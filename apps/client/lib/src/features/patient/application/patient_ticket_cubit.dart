import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api.dart';
import '../../../config.dart';
import '../data/patient_repository.dart';
import '../models/patient_models.dart';
import '../models/patient_ticket_dispatch.dart';

class PatientTicketState {
  const PatientTicketState({
    required this.snapshot,
    this.load = PatientLoad.initial,
    this.mutation = PatientMutation.idle,
    this.error,
    this.dispatch,
    this.dispatchLoading = false,
    this.dispatchError,
    this.dispatchConnected = false,
  });
  final PatientSnapshot snapshot;
  final PatientLoad load;
  final PatientMutation mutation;
  final String? error;
  final PatientTicketDispatch? dispatch;
  final bool dispatchLoading, dispatchConnected;
  final String? dispatchError;
}

class PatientTicketCubit extends Cubit<PatientTicketState> {
  PatientTicketCubit(this.repository, this.ticketId)
    : super(PatientTicketState(snapshot: repository.snapshot)) {
    repository.addListener(_changed);
    repository.invalidations.addListener(_invalidated);
    repository.updates.addListener(_queueInvalidated);
    repository.updates.queueSubscribed.addListener(_connectionChanged);
    repository.updates.status.addListener(_connectionChanged);
  }
  final PatientRepository repository;
  final String ticketId;
  bool _closing = false, _issuing = false;
  bool _verified = false, _loadingTicket = false, _ticketDirty = false;
  bool _dispatchLoading = false, _dispatchDirty = false;
  bool _lastConnection = false, _mismatchReconciled = false;
  int _dispatchRevision = 0;
  Future<void>? _pending, _dispatchPending;
  PatientTicketDispatch? _dispatch;
  String? _dispatchError;
  (String, String, String)? _ticketSignature;
  String get path => '/tiket/$ticketId';
  bool get current => !_closing && !isClosed && repository.active;
  Json? get ticket => state.snapshot.ticket(ticketId);
  Json? get _owned => repository.snapshot.ticket(ticketId);
  bool get canIssue =>
      current &&
      _verified &&
      state.load != PatientLoad.failure &&
      ticket?['status'] == 'DIPESAN' &&
      dateOnly(ticket?['tanggalPelayanan'] ?? ticket?['tanggalAntrean']) ==
          repository.api.config.today;

  (String, String, String)? get _signature {
    final owned = _owned;
    if (owned == null) return null;
    return (
      '${owned['status'] ?? ''}',
      dateOnly(owned['tanggalPelayanan'] ?? owned['tanggalAntrean']),
      '${object(owned['layanan'])['id'] ?? owned['layananId'] ?? ''}',
    );
  }

  PatientLoad get _load => !repository.active
      ? PatientLoad.sessionEnded
      : _loadingTicket
      ? _owned == null
            ? PatientLoad.loading
            : PatientLoad.refreshing
      : repository.errors.containsKey(path)
      ? PatientLoad.failure
      : _verified
      ? PatientLoad.loaded
      : PatientLoad.initial;

  PatientTicketDispatch? get _visibleDispatch {
    final value = _dispatch, owned = _owned;
    return current &&
            _verified &&
            !_loadingTicket &&
            !_dispatchLoading &&
            _dispatchError == null &&
            !repository.errors.containsKey(path) &&
            owned != null &&
            value != null &&
            value.matches(owned) &&
            value.freshAt(repository.api.config.now)
        ? value
        : null;
  }

  void _emit({
    PatientMutation? mutation,
    String? error,
    bool clearError = false,
  }) {
    if (_closing || isClosed) return;
    final visible = _visibleDispatch;
    final connected = repository.ticketDispatchConnected(ticketId);
    // A detail lease may reuse an already-acknowledged Home service without
    // emitting another socket notification. Track that state before publish.
    _lastConnection = connected;
    emit(
      PatientTicketState(
        snapshot: repository.snapshot,
        load: _load,
        mutation: repository.active
            ? mutation ?? state.mutation
            : PatientMutation.idle,
        error: !repository.active || clearError
            ? null
            : error ?? repository.errors[path]?.toString() ?? state.error,
        dispatch: visible,
        dispatchLoading: current && (_loadingTicket || _dispatchLoading),
        dispatchError: current ? _dispatchError : null,
        dispatchConnected:
            visible != null &&
            visible.date == repository.api.config.today &&
            connected,
      ),
    );
  }

  void _discardDispatch() {
    _dispatchRevision++;
    _dispatch = null;
    _dispatchError = null;
    _dispatchDirty = false;
    _dispatchLoading = false;
  }

  void _changed() {
    if (_closing || isClosed) return;
    if (!current) {
      _verified = false;
      _discardDispatch();
      repository.releaseTicketDispatchScope(this);
      _emit(clearError: true);
      return;
    }
    final changed = _ticketSignature != _signature;
    if (changed || repository.errors.containsKey(path)) {
      _ticketSignature = _signature;
      _discardDispatch();
    }
    if (_verified && !repository.errors.containsKey(path)) {
      repository.retainTicketDispatchScope(this, ticketId);
    } else {
      repository.releaseTicketDispatchScope(this);
    }
    _emit();
    if (changed &&
        _verified &&
        !_loadingTicket &&
        _pending == null &&
        !repository.errors.containsKey(path)) {
      unawaited(refreshDispatch());
    }
  }

  void _invalidated() {
    if (current && repository.invalidations.value.$2.contains('TIKET')) {
      unawaited(refresh());
    }
  }

  void _queueInvalidated() {
    if (!current || !_verified) return;
    final kinds = repository.updates.lastKinds;
    // The owned-ticket invalidation already schedules its canonical read and
    // one dispatch read. Passive proofs and services outside the shared cap
    // do not react to unrelated Home queue/catalog notifications.
    if (kinds.contains('TIKET') ||
        !repository.hasTicketDispatchScope(this, ticketId))
      return;
    final ids = repository.updates.lastQueueIds;
    final serviceId = _signature?.$3;
    if (kinds.contains('KATALOG') ||
        (kinds.contains('ANTREAN') &&
            (ids.isEmpty || ids.contains(serviceId)))) {
      unawaited(refreshDispatch());
    }
  }

  void _connectionChanged() {
    if (!current) return;
    final connected = repository.ticketDispatchConnected(ticketId);
    if (connected == _lastConnection) return;
    _lastConnection = connected;
    _discardDispatch();
    _emit();
    if (connected && _verified && !_loadingTicket) {
      unawaited(refreshDispatch());
    }
  }

  Future<void> refresh() => _refreshTicket(resetMismatch: true);

  Future<void> _refreshTicket({bool resetMismatch = false}) {
    if (!current) return Future.value();
    if (resetMismatch) _mismatchReconciled = false;
    _ticketDirty = true;
    _loadingTicket = true;
    _discardDispatch();
    _emit(clearError: true);
    return _pending ??= _drainTicket().whenComplete(() async {
      _pending = null;
      if (current && _ticketDirty) await _refreshTicket();
    });
  }

  Future<void> _drainTicket() async {
    try {
      while (current && _ticketDirty) {
        _ticketDirty = false;
        await repository.refresh([path]);
        if (!current) return;
        if (_ticketDirty) continue;
        _loadingTicket = false;
        _verified = _owned != null && !repository.errors.containsKey(path);
        _changed();
        if (_verified) await refreshDispatch();
      }
    } finally {
      _loadingTicket = false;
      _emit();
    }
  }

  /// One in-flight dispatch read plus a trailing read for invalidations.
  Future<void> refreshDispatch() {
    if (!current ||
        !_verified ||
        _loadingTicket ||
        _owned == null ||
        repository.errors.containsKey(path))
      return Future.value();
    _dispatchRevision++;
    _dispatchDirty = true;
    _dispatch = null;
    _dispatchError = null;
    _dispatchLoading = true;
    _emit();
    return _dispatchPending ??= _drainDispatch().whenComplete(() async {
      _dispatchPending = null;
      if (current && _dispatchDirty) await refreshDispatch();
    });
  }

  Future<void> _drainDispatch() async {
    try {
      while (current && _dispatchDirty && !_loadingTicket) {
        final revision = _dispatchRevision;
        _dispatchDirty = false;
        try {
          final result = await repository.readTicketDispatch(ticketId);
          if (!current) return;
          if (revision != _dispatchRevision) continue;
          final owned = _owned;
          if (owned == null || !result.matches(owned)) {
            _dispatchError = 'Status tiket berubah. Perbarui status antrean.';
            // At most one automatic owned-ticket reconciliation for a
            // persistent mismatch; do not turn a stale API into a retry loop.
            if (!_mismatchReconciled) {
              _mismatchReconciled = true;
              unawaited(_refreshTicket());
            }
            continue;
          }
          _mismatchReconciled = false;
          _dispatch = result;
          _dispatchError = null;
        } catch (_) {
          if (!current) return;
          if (revision != _dispatchRevision) continue;
          _dispatch = null;
          _dispatchError =
              'Posisi antrean belum dapat dimuat. Perbarui status.';
        }
      }
    } finally {
      _dispatchLoading = false;
      _emit();
    }
  }

  Future<PatientQr?> issue() async {
    repository.check();
    if (!canIssue || _issuing || _pending != null) {
      throw const ApiException(
        409,
        'QR tersedia untuk tiket DIPESAN pada hari pelayanan.',
      );
    }
    _issuing = true;
    _emit(mutation: PatientMutation.submitting, clearError: true);
    PatientQr? result;
    try {
      result = await repository.issueQr(ticketId);
      if (!current || !canIssue) {
        result.clear();
        return null;
      }
      _emit(mutation: PatientMutation.success);
      return result;
    } catch (error) {
      if (current) {
        await refresh();
        if (current) {
          _emit(
            mutation: uncertainPatient(error)
                ? PatientMutation.unknown
                : PatientMutation.failure,
            error: error is ApiException && error.status == 410
                ? 'QR sudah kedaluwarsa. Terbitkan QR baru untuk melanjutkan.'
                : '${patientError(error)}',
          );
        }
      }
      result?.clear();
      return null;
    } finally {
      _issuing = false;
    }
  }

  @override
  Future<void> close() {
    _closing = true;
    _dispatchRevision++;
    _ticketDirty = _dispatchDirty = false;
    repository.removeListener(_changed);
    repository.invalidations.removeListener(_invalidated);
    repository.updates.removeListener(_queueInvalidated);
    repository.updates.queueSubscribed.removeListener(_connectionChanged);
    repository.updates.status.removeListener(_connectionChanged);
    repository.releaseTicketDispatchScope(this);
    return super.close();
  }
}
