import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'routing/route_policy.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/patient/data/patient_repository.dart';
import 'features/patient/application/patient_overview_cubit.dart';
import 'features/patient/application/patient_booking_cubit.dart';
import 'features/patient/data/patient_booking_repository.dart';
import 'features/patient/models/patient_models.dart';
import 'features/patient/models/patient_queue_models.dart';
import 'features/patient/application/patient_reservations_cubit.dart';
import 'features/patient/application/patient_ticket_cubit.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'api.dart';
import 'config.dart';
import 'widgets.dart';
import 'mobile_ui.dart';
import 'queueb_feedback.dart';
import 'patient_design.dart';
import 'patient_agenda.dart';
import 'patient_sync.dart';
import 'doctor_schedule_ui.dart';
import 'patient_doctor_detail_ui.dart';
import 'doctor_professional.dart';
import 'patient_ui.dart';
import 'queueb_motion.dart';
import 'queueb_interaction_motion.dart';
import 'queueb_content_motion.dart';
import 'patient_home.dart';
import 'patient_home_appointment_card.dart';
import 'patient_home_v6.dart';
import 'patient_home_v7.dart';
import 'patient_home_v8.dart';
import 'patient_information.dart';
import 'patient_navigation.dart';
import 'user_profile.dart';
import 'patient_reservations.dart';
import 'patient_ticket_pdf.dart';
import 'patient_ticket_dispatch_ui.dart';
import 'patient_notifications.dart';
import 'patient_mobile_v5.dart';
import 'patient_scroll_shell.dart';

class PatientPage extends StatefulWidget {
  const PatientPage({
    super.key,
    required this.api,
    this.onDisplay,
    this.headerBuilder,
    this.repository,
    this.navigationShell,
    this.location,
  });
  final QueueApi api;
  final StatefulNavigationShell? navigationShell;
  final Uri? location;

  /// Optional externally-owned scope, useful for dependency injection.
  final PatientRepository? repository;
  final VoidCallback? onDisplay;
  final PreferredSizeWidget Function(bool home, VoidCallback activity)?
  headerBuilder;
  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  late final PatientRepository repository;
  late final PatientOverviewCubit overviewCubit;
  PatientUpdates get updates => repository.updates;
  late final PatientBookingCubit booking;
  late final PatientReservationsCubit reservations;
  int _tab = 0;
  int get tab => widget.navigationShell == null
      ? _tab
      : patientBranchTabs[widget.navigationShell!.currentIndex];
  set tab(int value) {
    if (widget.navigationShell == null) {
      _tab = value;
    } else if (value != 2) {
      final branch = patientBranchTabs.indexOf(value);
      if (branch >= 0) widget.navigationShell!.goBranch(branch);
    }
  }

  void _go(String path) {
    if (widget.navigationShell != null) context.go(path);
  }

  bool get _routedBooking =>
      widget.location?.path == '/patient/reservations/new' ||
      widget.location?.path.startsWith('/patient/reservations/doctors/') ==
          true;
  String? _hydratingUri, _routeError;
  bool _routeLoading = false;

  int get catalogRevision => booking.revision;
  bool profileVisited = false;
  bool get busy => reservations.busy || booking.busy;
  bool get loading =>
      [
        PatientLoad.initial,
        PatientLoad.loading,
        PatientLoad.refreshing,
      ].contains(overviewCubit.state.load) ||
      booking.state.loading;
  bool ticketDialogOpen = false, cancelReviewing = false;
  bool _reservationCreating = false;
  bool get reservationCreating =>
      widget.navigationShell == null ? _reservationCreating : _routedBooking;
  set reservationCreating(bool value) => _reservationCreating = value;
  bool get nearestLoading => booking.state.values['nearestLoading'] == true;
  set nearestLoading(bool value) => booking.change({'nearestLoading': value});
  String reservationMode = 'legacy', reservationQuery = '';
  String? reservationClinicId;
  String? get nearestError => booking.state.values['nearestError'] as String?;
  set nearestError(String? value) => booking.change({'nearestError': value});
  int reservationFlowVersion = 0;
  List<Json> get nearestChoices => booking.state.rows('nearestChoices');
  String? _error, message;
  String? get error =>
      _error ??
      booking.state.error ??
      reservations.state.error ??
      overviewCubit.state.error;
  set error(String? value) => _error = value;
  String? get serviceId => booking.serviceId;
  set serviceId(String? value) => booking.change({'serviceId': value});
  String? get doctorId => booking.doctorId;
  set doctorId(String? value) => booking.change({'doctorId': value});
  String? get sessionId => booking.sessionId;
  set sessionId(String? value) => booking.change({'sessionId': value});
  String? get slotId => booking.slotId;
  set slotId(String? value) => booking.change({'slotId': value});
  bool get appointment => booking.appointment;
  set appointment(bool value) => booking.change({'appointment': value});
  bool bookingStage = false, doctorDetail = false;
  bool reviewing = false;
  String search = '', channel = 'Semua';
  String homeQuery = '';
  final _homeEntrances = <String, QueueBMotionOnce>{};
  List<String>? _entranceServices;
  Widget _homeEntrance(Json service, Widget child) {
    final id = '${service['id']}';
    final ordinal = _entranceServices?.indexOf(id) ?? -1;
    if (ordinal < 0) return child;
    return QueueBContentEntrance(
      key: ValueKey(('home-service-motion', id)),
      once: _homeEntrances.putIfAbsent(id, QueueBMotionOnce.new),
      index: ordinal,
      child: child,
    );
  }

  PatientHomeMode homeMode = PatientHomeMode.walkIn;
  final homeSearch = TextEditingController();
  final _homeNestedScrollKey = GlobalKey<NestedScrollViewState>();
  String? homeClinicId;
  List<Json> get clinicSchedules => booking.state.rows('clinicSchedules');
  set clinicSchedules(List<Json> value) =>
      booking.change({'clinicSchedules': value});
  List<Json> get homeSchedules => overviewCubit.state.snapshot.schedules;
  String? get homeScheduleError => overviewCubit.state.scheduleError;
  Map<String, String> get clinicAvailability =>
      (booking.state.values['availability'] as Map? ?? const {})
          .cast<String, String>();
  List<Json> get services => overviewCubit.state.snapshot.services
      .where((s) => s['aktif'] != false)
      .toList();
  List<Json> get serviceHours => overviewCubit.state.snapshot.serviceHours;
  bool get hoursAvailable =>
      overviewCubit.state.snapshot.collections.containsKey('/jadwal-layanan') &&
      !overviewCubit.state.errors.containsKey('/jadwal-layanan');
  List<Json> get doctors => overviewCubit.state.snapshot.doctors
      .where((d) => d['aktif'] != false)
      .toList();
  List<Json> get schedules => booking.state.rows('schedules');
  set schedules(List<Json> value) => booking.change({'schedules': value});
  List<Json> get slots => booking.state.rows('slots');
  set slots(List<Json> value) => booking.change({'slots': value});
  List<Json> get tickets => reservations.state.snapshot.tickets;
  List<Json> get appointments => reservations.state.snapshot.appointments;
  late final date = TextEditingController(text: widget.api.config.today);
  Json? get selectedService =>
      services.where((s) => s['id'] == serviceId).firstOrNull;
  List<Json> get matchingDoctors => doctors
      .where(
        (d) =>
            d['aktif'] != false &&
            rows(d['dokterLayanan']).any(
              (l) =>
                  l['layananId'] == serviceId &&
                  l['aktif'] == true &&
                  object(l['layanan'])['aktif'] != false,
            ),
      )
      .toList();
  List<String> get practiceDates =>
      clinicSchedules
          .where(
            (s) =>
                s['aktif'] != false &&
                (object(s['dokterLayanan'])['dokterId'] == doctorId ||
                    object(object(s['dokterLayanan'])['dokter'])['id'] ==
                        doctorId),
          )
          .map((s) => dateOnly(s['tanggal']))
          .where((d) => d.compareTo(widget.api.config.today) >= 0)
          .toSet()
          .toList()
        ..sort();

  String doctorAvailability(Json doctor) {
    final future =
        clinicSchedules
            .where(
              (s) =>
                  s['aktif'] != false &&
                  (object(s['dokterLayanan'])['dokterId'] == doctor['id'] ||
                      object(object(s['dokterLayanan'])['dokter'])['id'] ==
                          doctor['id']) &&
                  dateOnly(s['tanggal']).compareTo(widget.api.config.today) >=
                      0,
            )
            .toList()
          ..sort((a, b) => '${a['mulaiPada']}'.compareTo('${b['mulaiPada']}'));
    if (loading) return 'Memuat jadwal praktik…';
    if (error != null) return 'Jadwal belum dapat dimuat. Coba lagi.';
    if (future.isEmpty) return 'Belum ada jadwal praktik mendatang.';
    return '${patientDate('${future.first['tanggal']}')} · ${patientTime(future.first, widget.api.config)}\n${clinicAvailability['${doctor['id']}'] ?? 'Lihat slot untuk ketersediaan aktual'}';
  }

  Future<void> loadClinicSchedules() => booking.loadClinicSchedules();

  Future<void> chooseDoctor(Json doctor) async {
    setState(() {
      doctorId = '${doctor['id']}';
      doctorDetail = true;
      appointment = selectedService?['modeReservasi'] != 'ANTREAN_HARIAN';
      final dates = practiceDates;
      if (!dates.contains(date.text) && dates.isNotEmpty) {
        date.text = dates.first;
      }
    });
    _go(
      Uri(
        path: '/patient/reservations/doctors/${doctor['id']}',
        queryParameters: serviceId == null ? null : {'clinic': serviceId!},
      ).toString(),
    );
    await loadSchedules();
  }

  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? PatientRepository(widget.api);
    overviewCubit = PatientOverviewCubit(repository);
    booking = PatientBookingCubit(PatientBookingRepository(repository));
    reservations = PatientReservationsCubit(repository);
    repository.addListener(_scopeChanged);
    unawaited(load().then((_) => _hydrateRoute()));
  }

  @override
  void didUpdateWidget(covariant PatientPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _routeLoading = false;
      _routeError = null;
      _hydratingUri = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_hydrateRoute());
      });
    }
  }

  Future<void> _hydrateRoute() async {
    final uri = widget.location;
    if (uri == null ||
        !_routedBooking ||
        !repository.active ||
        _hydratingUri == uri.toString()) {
      return;
    }
    _hydratingUri = uri.toString();
    final isDoctor = uri.path.startsWith('/patient/reservations/doctors/');
    final id = isDoctor ? uri.pathSegments.last : null;
    // An explicit UI selection is already validated by the feature.
    if (id != null &&
        doctorId == id &&
        serviceId == uri.queryParameters['clinic']) {
      return;
    }
    if (!isDoctor &&
        serviceId != null &&
        uri.queryParameters['clinic'] == serviceId) {
      return;
    }
    setState(() {
      _routeLoading = true;
      _routeError = null;
    });
    final expected = uri.toString();
    bool current() =>
        mounted && repository.active && widget.location?.toString() == expected;
    try {
      if (services.isEmpty || (isDoctor && doctors.isEmpty)) {
        await readOverview();
      }
      if (!current()) return;
      final clinic = uri.queryParameters['clinic'];
      if (isDoctor) {
        final doctor = doctors.where((d) => d['id'] == id).firstOrNull;
        final links = doctor == null
            ? <Json>[]
            : rows(doctor['dokterLayanan'])
                  .where(
                    (l) =>
                        l['aktif'] == true &&
                        services.any((s) => s['id'] == l['layananId']) &&
                        (clinic == null || l['layananId'] == clinic),
                  )
                  .toList();
        if (doctor == null || links.length != 1) {
          throw const ApiException(
            404,
            'Dokter atau poliklinik tidak tersedia. Pilih kembali dari daftar.',
          );
        }
        await _selectService('${links.single['layananId']}');
        if (!current()) return;
        setState(() {
          doctorId = id;
          doctorDetail = true;
          final dates = practiceDates;
          if (!dates.contains(date.text) && dates.isNotEmpty) {
            date.text = dates.first;
          }
        });
        await loadSchedules();
      } else {
        if (clinic != null) {
          if (!services.any((s) => s['id'] == clinic)) {
            throw const ApiException(404, 'Poliklinik tidak tersedia.');
          }
          await _selectService(clinic);
        } else {
          setState(() {
            _reservationCreating = true;
            reservationMode = uri.queryParameters['mode'] ?? 'doctors';
          });
        }
      }
    } catch (_) {
      if (current()) {
        setState(
          () => _routeError = 'Pilihan tidak tersedia. Kembali ke daftar reservasi dan pilih kembali.',
        );
      }
    } finally {
      if (current()) setState(() => _routeLoading = false);
    }
  }

  void _scopeChanged() {
    if (mounted && repository.active) {
      repository.configureQueueScope(
        homeWalkInClinics(
          repository.snapshot.services,
          repository.snapshot.doctors,
          '',
        ).map((s) => '${s['id']}'),
        widget.api.config.today,
      );
    }
    if (mounted && !repository.active) {
      setState(() {
        _error = message = null;
        reservationCreating = reviewing = cancelReviewing = false;
        homeSearch.clear();
        date.clear();
        homeQuery = search = reservationQuery = '';
      });
    }
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      error = null;
    });
    await readOverview();
  }

  Future<void> readOverview() async {
    await overviewCubit.refresh(
      paths: [1, 2, 3, 4].contains(tab) && !reservationCreating
          ? patientVisitPaths
          : patientOverviewPaths,
    );
    if (reservationCreating) await booking.refreshSelection();
    if (!mounted || !repository.active) return;
    setState(() => error = overviewCubit.state.error);
  }

  Future<void> loadSchedules() async {
    final requestedDate = date.text.trim();
    final requestedDoctor = doctorId;
    booking.change({'date': requestedDate});
    setState(() => bookingStage = true);
    await booking.loadSchedules();
    // One available session needs no second selection step. Load its slots
    // through the existing Cubit, never from a preview or a mock value.
    if (!mounted ||
        !repository.active ||
        !doctorDetail ||
        !appointment ||
        doctorId != requestedDoctor ||
        date.text.trim() != requestedDate ||
        booking.state.error != null) {
      return;
    }
    final validSessions = schedules
        .where((s) => dateOnly(s['tanggal']) == requestedDate)
        .toList();
    if (validSessions.length == 1 &&
        sessionId != '${validSessions.single['id']}') {
      await loadSlots('${validSessions.single['id']}');
    }
  }

  Future<void> loadSlots(String id) => booking.loadSlots(id);

  bool get _showDoctorDetail =>
      tab == 2 &&
      reservationCreating &&
      bookingStage &&
      doctorDetail &&
      serviceId != null &&
      doctorId != null;

  bool get _compactPatientPage =>
      tab == 0 || _showDoctorDetail || (tab == 2 && !reservationCreating);

  /// One selection predicate drives both the summary and the fixed action.
  /// The existing booking Cubit still validates again before confirmation.
  Json? get _selectedDoctorSlot {
    if (!appointment ||
        !schedules.any(
          (session) =>
              session['id'] == sessionId &&
              session['aktif'] != false &&
              dateOnly(session['tanggal']) == date.text.trim(),
        )) {
      return null;
    }
    return slots
        .where(
          (slot) =>
              slot['id'] == slotId &&
              slot['aktif'] != false &&
              slot['tersedia'] == true &&
              !(slot['sisaKapasitas'] is num && slot['sisaKapasitas'] <= 0),
        )
        .firstOrNull;
  }

  Widget _doctorBookingBar(BuildContext context) {
    final slot = _selectedDoctorSlot;
    final localTime = slot == null
        ? null
        : widget.api.config.localInput(slot['mulaiPada']).split('T').last;
    return PatientDoctorBookingBar(
      dateLabel: slot == null
          ? 'Pilih tanggal & jam'
          : patientCompactDate(date.text),
      timeLabel: slot == null
          ? 'Belum ada slot dipilih'
          : '$localTime ${patientHomeTimeZone(widget.api.config.serviceTimeZone)}',
      busy: busy,
      onConfirm:
          busy ||
              loading ||
              _routeLoading ||
              _routeError != null ||
              error != null ||
              slot == null
          ? null
          : book,
    );
  }

  Future<void> book() async {
    if (busy || reviewing) return;
    PatientBookingRequest request;
    try {
      request = booking.prepare(date.text.trim());
    } catch (e) {
      setState(() => error = '$e');
      return;
    }
    reviewing = true;
    final accepted = request.appointment
        ? await showDialog<bool>(
                context: context,
                animationStyle: QueueBMotion.modalStyle(context),
                builder: (_) => QueueBModalMotion(
                  child: AppointmentReview(
                    doctor: request.doctor,
                    clinic: request.clinic,
                    session: request.session,
                    slot: request.slot,
                    config: widget.api.config,
                  ),
                ),
              ) ==
              true
        : await confirm(
            context,
            'Daftarkan walk-in pada ${label(request.clinic)} tanggal ${request.date}?',
          );
    reviewing = false;
    if (!mounted || !accepted) return;
    setState(() {
      error = null;
      message = null;
    });
    try {
      final issued = await booking.submit(request);
      if (!mounted || !repository.active) return;
      setState(() {
        message =
            '${request.appointment ? 'Janji temu berhasil dibuat.' : 'Pendaftaran berhasil.'}${issued['nomorAntrean'] == null ? '' : ' Tiket ${issued['nomorAntrean']}.'} Tiket dapat dilihat di Reservasi.';
        // Legacy non-routed patient view uses its own tab state.
        if (widget.navigationShell == null) {
          tab = 2;
          reservationCreating = false;
        }
      });
      // The routed app keeps booking, QR and ticket detail routes intact,
      // but uses Reservasi as the single visible ticket/reservation list.
      if (widget.navigationShell != null) {
        context.go('/patient/reservations');
      }
    } catch (e) {
      if (mounted && repository.active) {
        setState(() => error = booking.state.error == null ? '$e' : null);
      }
    }
  }

  Future<void> cancel(Json appt) async {
    if (busy || cancelReviewing) return;
    cancelReviewing = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan reservasi?'),
        content: const Text(
          'Reservasi yang dibatalkan tidak dapat digunakan untuk check-in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    cancelReviewing = false;
    if (!mounted || accepted != true || busy) return;
    setState(() {
      error = null;
      message = null;
    });
    try {
      await reservations.cancel('${appt['id']}');
      if (mounted && repository.active) {
        setState(() => message = 'Reservasi dibatalkan.');
      }
    } catch (e) {
      if (mounted && repository.active) {
        setState(() => error = reservations.state.error == null ? '$e' : null);
      }
    }
  }

  Future<void> openTicket(Json ticket, {bool issueQrOnOpen = false}) async {
    if (ticketDialogOpen) return;
    ticketDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        animationStyle: QueueBMotion.modalStyle(context),
        builder: (context) => _TicketDialog(
          api: widget.api,
          repository: repository,
          ticket: ticket,
          issueQrOnOpen: issueQrOnOpen,
          onManage: showReservations,
          appointment: appointments
              .where((a) => object(a['tiket'])['id'] == ticket['id'])
              .firstOrNull,
        ),
      );
    } finally {
      ticketDialogOpen = false;
    }
    if (mounted) await load();
  }

  @override
  void dispose() {
    reservations.close();
    booking.close();
    overviewCubit.close();
    repository.removeListener(_scopeChanged);
    if (widget.repository == null) repository.dispose();
    date.dispose();
    homeSearch.dispose();
    super.dispose();
  }

  Future<void> selectService(String? value) {
    final pending = _selectService(value);
    _go(
      Uri(
        path: '/patient/reservations/new',
        queryParameters: value == null ? null : {'clinic': value},
      ).toString(),
    );
    return pending;
  }

  Future<void> _selectService(String? value) {
    setState(() {
      booking.invalidate();
      serviceId = value;
      reservationCreating = true;
      booking.clearAvailability();
      search = '';
      tab = 2;
      doctorDetail = false;
      doctorId = sessionId = slotId = null;
      schedules = [];
      slots = [];
      bookingStage = false;
      clinicSchedules = [];
      appointment = selectedService?['modeReservasi'] != 'ANTREAN_HARIAN';
      if (channel == 'Walk-in' &&
          selectedService?['modeReservasi'] != 'JANJI_TEMU_DOKTER') {
        appointment = false;
      }
    });
    return loadClinicSchedules();
  }

  void startRegistration(bool isAppointment) {
    setState(() {
      reservationCreating = true;
      reservationMode = 'legacy';
      booking.invalidateNearest();
      reservationFlowVersion++;
      tab = 2;
      channel = isAppointment ? 'Janji temu' : 'Walk-in';
      booking.clearAvailability();
      appointment = isAppointment;
      bookingStage = false;
      doctorDetail = false;
      serviceId = doctorId = sessionId = slotId = null;
      booking.invalidate();
      schedules = [];
      slots = [];
      search = '';
      clinicSchedules = [];
    });
  }

  void showReservations() {
    if (busy) return;
    setState(() {
      tab = 2;
      reservationCreating = false;
      booking.invalidate();
      booking.invalidateNearest();
      reservationFlowVersion++;
    });
    widget.navigationShell?.goBranch(1, initialLocation: true);
  }

  Future<void> createReservation() async {
    if (busy || loading) return;
    final method = await chooseReservationMethod(context);
    if (!mounted || method == null || busy) return;
    setState(() {
      tab = 2;
      reservationCreating = true;
      reservationMode = method;
      nearestLoading = false;
      nearestError = null;
      reservationQuery = '';
      reservationClinicId = null;
      serviceId = doctorId = sessionId = slotId = null;
      bookingStage = doctorDetail = false;
      channel = 'Semua';
      search = '';
      error = message = null;
      clinicSchedules = schedules = slots = [];
      booking.invalidate();
      booking.invalidateNearest();
      reservationFlowVersion++;
    });
    _go(
      Uri(
        path: '/patient/reservations/new',
        queryParameters: {'mode': method},
      ).toString(),
    );
    if (method == 'nearest') await loadNearest();
  }

  Future<void> loadNearest() => booking.loadNearest();

  Future<void> chooseReservationDoctor(
    Json doctor,
    Json clinic, {
    Json? session,
    Json? slot,
  }) async {
    if (busy || loading) return;
    final version = ++reservationFlowVersion;
    booking.invalidateNearest();
    await selectService('${clinic['id']}');
    if (!mounted || version != reservationFlowVersion || tab != 2) return;
    if (session != null) date.text = dateOnly(session['tanggal']);
    await chooseDoctor(doctor);
    if (!mounted || version != reservationFlowVersion || tab != 2) return;
    // Keep the nearest booking on the doctor detail route. A single session
    // may already have been loaded automatically by loadSchedules().
    if (session != null && schedules.any((s) => s['id'] == session['id'])) {
      if (sessionId != '${session['id']}') {
        await loadSlots('${session['id']}');
      }
      if (mounted &&
          version == reservationFlowVersion &&
          slot != null &&
          slots.any((s) => s['id'] == slot['id'] && s['tersedia'] == true)) {
        setState(() => slotId = '${slot['id']}');
      }
    }
  }

  Widget reservationDoctors(BuildContext context) {
    final nearest = reservationMode == 'nearest';
    final choices = <Json>[];
    if (nearest) {
      choices.addAll(nearestChoices);
    } else {
      for (final doctor in doctors) {
        for (final link in rows(
          doctor['dokterLayanan'],
        ).where((l) => l['aktif'] == true)) {
          final clinic = services
              .where(
                (c) =>
                    c['id'] ==
                        (link['layananId'] ?? object(link['layanan'])['id']) &&
                    c['modeReservasi'] != 'ANTREAN_HARIAN',
              )
              .firstOrNull;
          if (clinic == null) continue;
          final sessions = booking.reservableSessions.where((s) {
            final pair = object(s['dokterLayanan']);
            return (pair['dokterId'] ?? object(pair['dokter'])['id']) ==
                    doctor['id'] &&
                (pair['layananId'] ?? object(pair['layanan'])['id']) ==
                    clinic['id'];
          });
          choices.add({
            'doctor': doctor,
            'clinic': clinic,
            'session': sessions.firstOrNull,
          });
        }
      }
    }
    final visible = choices
        .where(
          (c) =>
              (reservationClinicId == null ||
                  object(c['clinic'])['id'] == reservationClinicId) &&
              ('${label(object(c['doctor']))} ${object(c['doctor'])['spesialisasi'] ?? ''} ${label(object(c['clinic']))}')
                  .toLowerCase()
                  .contains(reservationQuery),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatientHeading(
          title: nearest ? 'Jadwal Terdekat' : 'Buat Reservasi',
          onBack: showReservations,
        ),
        TextField(
          key: ValueKey(reservationMode),
          onChanged: (v) =>
              setState(() => reservationQuery = v.toLowerCase().trim()),
          decoration: const InputDecoration(
            hintText: 'Cari dokter, poliklinik, atau spesialisasi...',
            hintStyle: TextStyle(fontSize: 12),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in [
                <String, dynamic>{'id': null, 'nama': 'Semua'},
                ...services.where(
                  (c) => c['modeReservasi'] != 'ANTREAN_HARIAN',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label(c)),
                    showCheckmark: false,
                    selected: reservationClinicId == c['id'],
                    onSelected: (_) =>
                        setState(() => reservationClinicId = c['id']),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (nearestLoading)
          const LinearProgressIndicator(semanticsLabel: 'Membaca slot aktual'),
        if (nearestError != null && nearest)
          MobileNotice(nearestError!, error: true),
        if (homeScheduleError != null && !nearest)
          MobileNotice(homeScheduleError!, error: true),
        if (visible.isEmpty && !nearestLoading && !loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              nearest
                  ? 'Belum ada slot tersedia yang sesuai.'
                  : 'Tidak ada dokter yang sesuai.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PatientDesign.muted),
            ),
          ),
        // The outer booking list owns scrolling. Only the nearest view is bounded
        // locally; a limited page avoids eagerly building every available slot.
        ReservationChoices(
          choices: visible,
          config: widget.api.config,
          busy: busy || loading,
          onSelect: (c) => chooseReservationDoctor(
            object(c['doctor']),
            object(c['clinic']),
            session: c['slot'] == null ? null : object(c['session']),
            slot: c['slot'] == null ? null : object(c['slot']),
          ),
        ),
        OutlinedButton.icon(
          onPressed: busy || loading || nearestLoading
              ? null
              : () async {
                  await load();
                },
          icon: const Icon(Icons.refresh),
          label: const Text('Muat ulang pilihan'),
        ),
      ],
    );
  }

  List<Json> clinicsForQuery(String query) => services
      .where(
        (clinic) =>
            label(clinic).toLowerCase().contains(query) ||
            doctors.any(
              (doctor) =>
                  ('${label(doctor)} ${doctor['spesialisasi'] ?? ''}')
                      .toLowerCase()
                      .contains(query) &&
                  rows(doctor['dokterLayanan']).any(
                    (link) =>
                        link['layananId'] == clinic['id'] &&
                        link['aktif'] == true,
                  ),
            ),
      )
      .toList();

  Widget _home(BuildContext context) {
    final active = nearestHomeTicket(
      tickets,
      appointments,
      widget.api.config.today,
    );
    final visit = appointments
        .where((a) => object(a['tiket'])['id'] == active?['id'])
        .firstOrNull;
    final appointmentClinics = services.where(supportsHomeAppointment).toList();
    final directoryAvailable = const ['/dokter', '/layanan', '/jadwal-praktik']
        .every(
          (path) =>
              overviewCubit.state.snapshot.collections.containsKey(path) &&
              !overviewCubit.state.errors.containsKey(path),
        );
    final directoryError =
        homeScheduleError ??
        (!loading && !directoryAvailable
            ? 'Daftar dokter atau layanan belum dapat dimuat. Silakan muat ulang.'
            : null);
    final previews = homeDoctorPreviews(
      doctors,
      appointmentClinics,
      homeSchedules,
      widget.api.config,
      homeQuery,
      clinicId: appointmentClinics.any((c) => c['id'] == homeClinicId)
          ? homeClinicId
          : null,
    );
    final walkIns = homeWalkInClinics(services, doctors, homeQuery);
    if (!loading && walkIns.isNotEmpty) {
      _entranceServices ??= walkIns.take(5).map((s) => '${s['id']}').toList();
    }
    return PatientNativeHomeTabs(
      tabsFirst: false,
      nestedScrollKey: _homeNestedScrollKey,
      walkInSelected: homeMode == PatientHomeMode.walkIn,
      onChanged: busy
          ? null
          : (walkIn) => setState(() {
              homeMode = walkIn
                  ? PatientHomeMode.walkIn
                  : PatientHomeMode.values.firstWhere(
                      (mode) => mode != PatientHomeMode.walkIn,
                    );
            }),
      headerSlivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Memuat data pelayanan',
                  ),
                ListenableBuilder(
                  listenable: widget.api,
                  builder: (_, _) => PatientHomeWelcomeV8(
                    name: '${widget.api.user?['nama'] ?? 'Pasien'}',
                    now: widget.api.config.now,
                    appointmentMode: homeMode != PatientHomeMode.walkIn,
                    controller: homeSearch,
                    onSearch: (v) =>
                        setState(() => homeQuery = v.toLowerCase().trim()),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  MobileNotice(error!, error: true),
                  TextButton.icon(
                    onPressed: busy || loading ? null : load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
                ValueListenableBuilder<String>(
                  valueListenable: updates.status,
                  builder: (_, status, _) =>
                      status.contains('terputus') ||
                          status.contains('belum tersambung')
                      ? const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Koneksi terputus. Data terakhir ditampilkan; pembaruan berkala tetap berjalan.',
                            style: TextStyle(
                              fontSize: 12,
                              color: PatientDesign.muted,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),
                PatientHomeVisitV8(
                  ticket: active,
                  appointment: visit,
                  config: widget.api.config,
                  loading: loading,
                  unavailable: error != null,
                  onOpen: busy || active == null
                      ? null
                      : () => openTicket(active),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ],
      walkInSlivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          sliver: SliverToBoxAdapter(
            child: ValueListenableBuilder<PatientQueueState>(
              valueListenable: overviewCubit.queueState,
              builder: (context, queue, _) => PatientHomeListHeading(
                title: 'Daftar Antrean Langsung',
                caption: 'Walk-in',
                showLive: !loading && walkIns.isNotEmpty,
                live:
                    walkIns.isNotEmpty &&
                    walkIns.every(
                      (service) => queue
                          .forService(
                            '${service['id']}',
                            widget.api.config.today,
                          )
                          .live,
                    ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: loading
              ? const SliverToBoxAdapter(child: PatientHomeLoading())
              : walkIns.isEmpty
              ? const SliverToBoxAdapter(
                  child: PatientHomeEmpty(
                    text: 'Tidak ada layanan antrean harian yang sesuai pencarian.',
                  ),
                )
              : SliverList.builder(
                  itemCount: walkIns.length,
                  itemBuilder: (context, index) => _homeEntrance(
                    walkIns[index],
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ValueListenableBuilder<PatientQueueState>(
                        valueListenable: overviewCubit.queueState,
                        builder: (context, queue, _) {
                          final ownTicket = homeServiceTicket(
                            tickets,
                            '${walkIns[index]['id']}',
                            widget.api.config.today,
                            widget.api.user?['id']?.toString(),
                          );
                          return PatientHomeService(
                            clinic: walkIns[index],
                            hours: patientServiceHours(
                              serviceHours,
                              '${walkIns[index]['id']}',
                              widget.api.config.today,
                              available: hoursAvailable,
                            ),
                            timeZoneLabel: patientHomeTimeZone(
                              widget.api.config.serviceTimeZone,
                            ),
                            staffName: patientServiceProviderLabel(
                              doctors: doctors,
                              sessions: homeSchedules,
                              serviceId: '${walkIns[index]['id']}',
                              date: widget.api.config.today,
                            ),
                            queue: queue.forService(
                              '${walkIns[index]['id']}',
                              widget.api.config.today,
                            ),
                            ticket: ownTicket,
                            onTap: busy
                                ? null
                                : () {
                                    if (ownTicket != null) {
                                      openTicket(ownTicket);
                                      return;
                                    }
                                    startRegistration(false);
                                    selectService('${walkIns[index]['id']}');
                                  },
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sync_rounded,
                  size: 17,
                  color: PatientDesign.muted,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Data antrean diperbarui otomatis · Waktu layanan ${patientHomeTimeZone(widget.api.config.serviceTimeZone)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: PatientDesign.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      appointmentSlivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final clinic in <Json>[
                        {'nama': 'Semua layanan'},
                        ...appointmentClinics,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(label(clinic)),
                            selected: clinic['id'] == homeClinicId,
                            showCheckmark: false,
                            selectedColor: PatientDesign.primary,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(
                              color: clinic['id'] == homeClinicId
                                  ? PatientDesign.primary
                                  : PatientDesign.border,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: clinic['id'] == homeClinicId
                                  ? Colors.white
                                  : PatientDesign.ink,
                            ),
                            onSelected: busy
                                ? null
                                : (_) => setState(
                                    () =>
                                        homeClinicId = clinic['id'] as String?,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PatientHomeListHeading(
                    title: 'Dokter Hari Ini',
                    caption: loading
                        ? 'Memuat jadwal…'
                        : !directoryAvailable
                        ? 'Data dokter belum tersedia'
                        : '${previews.length} dokter · ${patientCompactDate(widget.api.config.today)}',
                  ),
                ),
                if (directoryError != null)
                  PatientHomeEmpty(
                    text: directoryError,
                    action: 'Muat ulang jadwal',
                    onPressed: busy || loading ? null : load,
                  ),
                if (loading)
                  const PatientHomeLoading()
                else if (directoryAvailable && previews.isEmpty)
                  PatientHomeEmpty(
                    text: homeQuery.isEmpty && homeClinicId == null
                        ? 'Belum ada dokter dengan jadwal praktik hari ini.'
                        : 'Tidak ada dokter praktik hari ini yang sesuai pencarian atau poliklinik.',
                  ),
              ],
            ),
          ),
        ),
        if (!loading && directoryAvailable)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList.builder(
              itemCount: previews.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PatientHomeAppointmentCard(
                  preview: previews[index],
                  config: widget.api.config,
                  scheduleUnavailable: homeScheduleError != null,
                  onTap: busy
                      ? null
                      : () async {
                          startRegistration(true);
                          final pending = selectService(
                            '${previews[index].clinic['id']}',
                          );
                          final revision = catalogRevision;
                          await pending;
                          if (mounted &&
                              revision == catalogRevision &&
                              error == null &&
                              (widget.navigationShell == null
                                  ? tab == 2
                                  : GoRouter.of(this.context)
                                        .routeInformationProvider
                                        .value
                                        .uri
                                        .path
                                        .startsWith(
                                          '/patient/reservations/',
                                        ))) {
                            await chooseDoctor(previews[index].doctor);
                          }
                        },
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: PatientHomeOtherSchedules(
              onOpen: busy || loading ? null : createReservation,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: overviewCubit),
      BlocProvider.value(value: booking),
      BlocProvider.value(value: reservations),
    ],
    child: BlocBuilder<PatientOverviewCubit, PatientOverviewState>(
      builder: (context, _) =>
          BlocConsumer<PatientBookingCubit, PatientBookingState>(
            listener: (context, state) {
              if (bookingStage && (serviceId == null || doctorId == null)) {
                setState(() {
                  bookingStage = doctorDetail = false;
                });
              }
            },
            builder: (context, _) =>
                BlocBuilder<PatientReservationsCubit, PatientReservationsState>(
                  builder: (context, _) => content(context),
                ),
          ),
    ),
  );

  Widget content(BuildContext context) => !repository.active
      ? const SizedBox.shrink()
      : Theme(
          data: PatientMobileV5.theme,
          child: _PatientViewScope(
            owner: this,
            child: PopScope(
              canPop:
                  kIsWeb ||
                  widget.navigationShell == null ||
                  (!busy &&
                      (tab == 0 ||
                          !RoutePolicy.patientPaths.contains(
                            widget.location?.path,
                          ))),
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop &&
                    !kIsWeb &&
                    !busy &&
                    widget.navigationShell != null) {
                  widget.navigationShell!.goBranch(0);
                }
              },
              child: PatientScrollShell(
                pageKey:
                    '$tab:${tab == 0 ? homeMode.name : ''}:$reservationCreating:$serviceId:$bookingStage:$doctorDetail',
                header: _showDoctorDetail
                    ? PatientDoctorDetailHeader(
                        height: PatientDoctorDetailHeader.heightFor(context),
                        onBack: busy || loading ? null : _backFromBookingDetail,
                        avatar: AccountAvatar(api: widget.api, radius: 18),
                        onProfile: busy || loading
                            ? null
                            : () {
                                if (widget.navigationShell == null) {
                                  setState(() => tab = 5);
                                } else {
                                  _go('/patient/profile');
                                }
                              },
                      )
                    : tab == 0 || (tab == 2 && !reservationCreating)
                    ? PatientHomeAppBarV8(
                        api: widget.api,
                        maxWidth: _compactPatientPage ? 480 : 680,
                        height: PatientHomeAppBarV8.heightFor(context),
                        onProfile: () {
                          if (widget.navigationShell == null) {
                            setState(() => tab = 5);
                          } else {
                            _go('/patient/profile');
                          }
                        },
                        onNotifications: () => showDialog<void>(
                          context: context,
                          builder: (c) => PatientNotificationsDialog(
                            repository: repository,
                          ),
                        ),
                      )
                    : null,
                acceptNestedScrolls: tab == 0,
                nestedScrollKey: tab == 0 ? _homeNestedScrollKey : null,
                activeNestedScrollKey: tab == 0
                    ? PageStorageKey<String>(
                        homeMode == PatientHomeMode.walkIn
                            ? 'patient-home-walk-in-scroll'
                            : 'patient-home-appointments-scroll',
                      )
                    : null,
                keepBottomNavigationVisible: _showDoctorDetail && appointment,
                bottomNavigationBar: _showDoctorDetail && appointment
                    ? _doctorBookingBar(context)
                    : PatientBottomNavigation(
                        maxWidth: _compactPatientPage ? 480 : 680,
                        selectedIndex: patientBottomIndex(tab),
                        onSelected: busy
                            ? null
                            : (i) {
                                if (widget.navigationShell case final shell?) {
                                  reservationFlowVersion++;
                                  booking.invalidateNearest();
                                  if (i == 1) {
                                    showReservations();
                                  } else {
                                    shell.goBranch(patientBottomBranches[i]);
                                  }
                                } else {
                                  setState(() {
                                    tab = patientBottomTabs[i];
                                    if (tab == 5) profileVisited = true;
                                    reservationFlowVersion++;
                                    booking.invalidateNearest();
                                    if (tab == 2) reservationCreating = false;
                                  });
                                }
                              },
                      ),
                body: ColoredBox(
                  color: tab == 0
                      ? PatientHomeV8Style.background
                      : PatientDesign.background,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _compactPatientPage ? 480 : 760,
                      ),
                      child:
                          widget.navigationShell ??
                          IndexedStack(
                            index: tab == 5
                                ? 2
                                : tab == 2 && !reservationCreating
                                ? 0
                                : 1,
                            children: [
                              _reservationHistory(),
                              tab == 0
                                  ? _home(context)
                                  : tab == 1
                                  ? _reservationHistory()
                                  : tab == 3
                                  ? PatientAgenda(
                                      appointments: appointments,
                                      config: widget.api.config,
                                      loading: loading,
                                      busy: busy,
                                      error: error,
                                      message: message,
                                      onRefresh: load,
                                      onTicket: (ticket) => openTicket(ticket),
                                    )
                                  : tab == 6
                                  ? _information()
                                  : ListView(
                                      key: PageStorageKey(
                                        '$tab:$serviceId:$bookingStage:$doctorDetail',
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                        if (error != null) ...[
                                          MobileNotice(error!, error: true),
                                          TextButton.icon(
                                            onPressed: busy || loading
                                                ? null
                                                : load,
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('Coba lagi'),
                                          ),
                                        ],
                                        if (message != null)
                                          MobileNotice(message!, success: true),
                                        if (loading)
                                          const LinearProgressIndicator(
                                            semanticsLabel:
                                                'Memuat data pelayanan',
                                          ),
                                        if (tab == 2) _registration(context),
                                        if (tab == 4) _history(context),
                                      ],
                                    ),
                              if (profileVisited)
                                UserProfilePage(
                                  api: widget.api,
                                  onReturnToPatient: () =>
                                      setState(() => tab = 0),
                                )
                              else
                                const SizedBox(),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

  Widget branch(BuildContext context, int index, {bool bookingView = false}) {
    if (!repository.active) return const SizedBox.shrink();
    return switch (index) {
      0 => _home(context),
      1 =>
        bookingView
            ? ListView(
                key: const PageStorageKey('booking-route'),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_routeLoading) const LinearProgressIndicator(),
                  if (error != null) ...[
                    MobileNotice(error!, error: true),
                    TextButton.icon(
                      onPressed: busy || loading ? null : load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                  if (loading) const LinearProgressIndicator(),
                  if (message != null) MobileNotice(message!, success: true),
                  if (_routeError != null) ...[
                    MobileNotice(_routeError!, error: true),
                    TextButton(
                      onPressed: showReservations,
                      child: const Text('Kembali ke reservasi'),
                    ),
                  ] else if (!_routeLoading)
                    _registration(context),
                ],
              )
            : _reservationHistory(),
      // Kept for legacy branch identity and ticket-detail deep links only.
      2 => _reservationHistory(),
      3 => PatientAgenda(
        appointments: appointments,
        config: widget.api.config,
        loading: loading,
        busy: busy,
        error: error,
        message: message,
        onRefresh: load,
        onTicket: (ticket) => openTicket(ticket),
      ),
      4 => UserProfilePage(
        api: widget.api,
        onReturnToPatient: () => widget.navigationShell!.goBranch(0),
      ),
      5 => _information(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _information() => PatientInformation(
    services: services,
    hours: serviceHours,
    date: widget.api.config.today,
    timeZone: widget.api.config.serviceTimeZone,
    hoursAvailable: hoursAvailable,
    loading: loading,
    error: error,
    hoursError: overviewCubit.state.errors.containsKey('/jadwal-layanan')
        ? 'Jam operasional belum dapat dimuat. Coba muat ulang informasi.'
        : null,
    onRefresh: busy || loading ? null : load,
  );

  /// Booking controls live inside the *same* schedule card as the month/day
  /// picker. The Cubit remains authoritative for sessions, slots and mutation.
  Widget _doctorScheduleBooking(BuildContext context) {
    final day = date.text.trim();
    final availableSessions =
        schedules.where((s) => dateOnly(s['tanggal']) == day).toList()..sort(
          (a, b) =>
              '${a['mulaiPada'] ?? ''}'.compareTo('${b['mulaiPada'] ?? ''}'),
        );
    final sessionIds = availableSessions.map((s) => '${s['id']}').toSet();
    final selected = sessionId != null && sessionIds.contains(sessionId);
    final availableSlots = selected ? slots : <Json>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Memuat jadwal dan slot konsultasi',
          ),
        if (!loading && availableSessions.isEmpty && error == null)
          const Text('Tidak ada sesi konsultasi pada tanggal ini.'),
        if (availableSessions.length > 1) ...[
          const Text(
            'Pilih sesi praktik',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PatientDesign.navy,
            ),
          ),
          const SizedBox(height: 6),
        ],
        // A session is represented exactly once: time, room and its selection.
        for (final session in availableSessions) ...[
          OutlinedButton(
            onPressed: busy || loading
                ? null
                : () => loadSlots('${session['id']}'),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              backgroundColor: sessionId == '${session['id']}'
                  ? PatientDesign.soft
                  : PatientHomeV8Style.background,
              foregroundColor: PatientDesign.ink,
              side: BorderSide(
                color: sessionId == '${session['id']}'
                    ? PatientDesign.primary
                    : PatientDesign.border,
              ),
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PatientDesign.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.wb_twilight_outlined,
                    color: PatientDesign.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Sesi praktik',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (sessionId == '${session['id']}')
                            const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: PatientDesign.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${patientTime(session, widget.api.config)} '
                        '${patientHomeTimeZone(widget.api.config.serviceTimeZone)}',
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _doctorRoomLabel(object(session['loket'])),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: PatientDesign.muted,
                        ),
                      ),
                      if (availableSessions.length > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          sessionId == '${session['id']}'
                              ? 'Sesi terpilih'
                              : 'Ketuk untuk melihat slot',
                          style: const TextStyle(
                            fontSize: 11,
                            color: PatientDesign.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (selected && !loading && availableSlots.isEmpty)
          const EmptyState(text: 'Belum ada slot konsultasi pada sesi ini.'),
        if (selected && availableSlots.isNotEmpty) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Pilih Jam Konsultasi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PatientDesign.navy,
                ),
              ),
              Text(
                patientHomeTimeZone(widget.api.config.serviceTimeZone),
                style: const TextStyle(
                  fontSize: 11,
                  color: PatientDesign.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Ketersediaan mengikuti data terbaru dari server.',
            style: TextStyle(fontSize: 12, color: PatientDesign.muted),
          ),
          const SizedBox(height: 8),
          if (!availableSlots.any((s) => s['tersedia'] == true))
            EmptyState(
              text:
                  availableSlots.every(
                    (s) => consultationSlotStatus(s) == 'Penuh',
                  )
                  ? 'Seluruh slot penuh. Pilih tanggal atau sesi lain.'
                  : 'Tidak ada slot yang dapat dipesan pada sesi ini.',
            ),
          ConsultationSlotGrid(
            slots: availableSlots,
            config: widget.api.config,
            value: slotId,
            enabled: !busy && !loading,
            onChanged: (value) => setState(() => slotId = value),
          ),
        ],
      ],
    );
  }

  String _doctorRoomLabel(Json room) {
    if (room.isEmpty) return 'Belum ditentukan';
    final code = '${room['kode'] ?? ''}'.trim();
    final name = label(room).trim();
    if (code.isEmpty) return name.isEmpty ? 'Belum ditentukan' : name;
    return name.isEmpty || name == code ? code : '$code · $name';
  }

  /// Return to the real entry point instead of recreating a service catalog.
  /// A doctor opened from Home can still step back to the service detail;
  /// doctor/nearest searches return directly to their filtered result list.
  void _backFromBookingDetail() {
    if (busy || loading) return;
    final fromSearch = const {'doctors', 'nearest'}.contains(reservationMode);
    final doctorRoute =
        widget.location?.path.startsWith('/patient/reservations/doctors/') ==
        true;
    final previousClinicId = serviceId;

    if (doctorRoute && !fromSearch && previousClinicId != null) {
      setState(() {
        booking.invalidate();
        bookingStage = doctorDetail = false;
        doctorId = sessionId = slotId = null;
        schedules = [];
        slots = [];
      });
      _go(
        Uri(
          path: '/patient/reservations/new',
          queryParameters: {'clinic': previousClinicId},
        ).toString(),
      );
      return;
    }

    setState(() {
      booking.invalidate();
      bookingStage = doctorDetail = false;
      serviceId = doctorId = sessionId = slotId = null;
      schedules = [];
      slots = [];
      clinicSchedules = [];
      search = '';
      if (widget.navigationShell == null) {
        reservationCreating = fromSearch;
        tab = fromSearch ? 2 : 0;
      }
    });
    if (fromSearch) {
      _go(
        Uri(
          path: '/patient/reservations/new',
          queryParameters: {'mode': reservationMode},
        ).toString(),
      );
      if (reservationMode == 'nearest') unawaited(loadNearest());
    } else {
      _go('/patient');
    }
  }

  Widget _registration(BuildContext context) {
    if (serviceId == null) {
      if (const {'doctors', 'nearest'}.contains(reservationMode)) {
        return reservationDoctors(context);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PatientHeading(title: 'Reservasi', onBack: showReservations),
          const MobileNotice(
            'Pilih layanan walk-in dari Beranda, atau gunakan Cari Dokter '
            'dan Jadwal Terdekat pada menu Reservasi.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () {
                    if (widget.navigationShell != null) {
                      _go('/patient');
                    } else {
                      setState(() {
                        reservationCreating = false;
                        tab = 0;
                      });
                    }
                  },
            icon: const Icon(Icons.home_outlined),
            label: const Text('Kembali ke Beranda'),
          ),
        ],
      );
    }
    final doctor =
        doctors.where((d) => d['id'] == doctorId).firstOrNull ??
        <String, dynamic>{};
    final dates = practiceDates;
    final clinicName = label(selectedService ?? {});
    final doctorSessions = clinicSchedules
        .where(
          (session) =>
              session['aktif'] != false &&
              dateOnly(session['tanggal']).compareTo(widget.api.config.today) >=
                  0 &&
              (object(session['dokterLayanan'])['dokterId'] == doctorId ||
                  object(object(session['dokterLayanan'])['dokter'])['id'] ==
                      doctorId),
        )
        .toList();
    final scheduleColor = loading || error != null || doctorSessions.isEmpty
        ? PatientDesign.muted
        : PatientDesign.success;
    final visibleDoctors = matchingDoctors
        .where(
          (d) =>
              clinicName.toLowerCase().contains(search) ||
              ('${label(d)} ${d['spesialisasi'] ?? ''}').toLowerCase().contains(
                search,
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_showDoctorDetail)
          PatientHeading(
            title: bookingStage ? 'Detail Dokter' : clinicName,
            onBack: busy || loading ? null : _backFromBookingDetail,
          ),
        if (!bookingStage) ...[
          if (selectedService != null) ...[
            SegmentedButton<bool>(
              segments: [
                if (selectedService!['modeReservasi'] != 'ANTREAN_HARIAN')
                  const ButtonSegment(value: true, label: Text('Janji temu')),
                if (selectedService!['modeReservasi'] != 'JANJI_TEMU_DOKTER')
                  const ButtonSegment(value: false, label: Text('Walk-in')),
              ],
              selected: {appointment},
              onSelectionChanged: busy || loading
                  ? null
                  : (v) {
                      setState(() {
                        booking.invalidate();
                        appointment = v.first;
                        doctorId = sessionId = slotId = null;
                        schedules = [];
                        slots = [];
                      });
                      if (appointment) loadClinicSchedules();
                    },
            ),
            const SizedBox(height: 16),
            ...[
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Cari nama dokter atau spesialisasi',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => search = v.toLowerCase().trim()),
              ),
              const SizedBox(height: 16),
              if (visibleDoctors.isEmpty && !loading)
                EmptyState(
                  text: matchingDoctors.isEmpty
                      ? 'Belum ada dokter pada poliklinik ini.'
                      : 'Tidak ada dokter yang sesuai pencarian.',
                ),
              for (final d in visibleDoctors)
                PatientDoctorCard(
                  doctor: d,
                  config: widget.api.config,
                  schedule: doctorAvailability(d),
                  onDetails: busy || loading ? null : () => chooseDoctor(d),
                ),
            ],
          ],
        ],
        if (bookingStage && doctorDetail) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  loading ? Icons.schedule_outlined : Icons.circle,
                  size: loading ? 16 : 9,
                  color: scheduleColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loading
                        ? 'MEMUAT JADWAL PRAKTIK'
                        : error != null
                        ? 'JADWAL BELUM DAPAT DIMUAT'
                        : doctorSessions.any(
                            (session) =>
                                dateOnly(session['tanggal']) ==
                                widget.api.config.today,
                          )
                        ? 'JADWAL PRAKTIK HARI INI'
                        : dates.isNotEmpty
                        ? 'JADWAL PRAKTIK MENDATANG'
                        : 'JADWAL BELUM TERSEDIA',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                      color: scheduleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          DoctorProfileCard(
            doctor: doctor,
            config: widget.api.config,
            clinics: clinicName,
            detail: true,
          ),
          const SizedBox(height: 8),
          _PatientDoctorSchedulePicker(
            key: ValueKey(('doctor-schedule', doctorId)),
            dates: dates,
            sessions: doctorSessions,
            value: date.text,
            config: widget.api.config,
            enabled: !busy && !loading,
            loading: loading,
            showSessionDetails:
                selectedService?['modeReservasi'] == 'ANTREAN_HARIAN',
            footer: selectedService?['modeReservasi'] == 'ANTREAN_HARIAN'
                ? null
                : _doctorScheduleBooking(context),
            onChanged: (day) {
              if (busy || loading || day == date.text) return;
              // Clear old selections immediately. Never render a slot from
              // another day as a selection for the newly displayed date.
              setState(() {
                date.text = day;
                sessionId = slotId = null;
                schedules = [];
                slots = [];
              });
              unawaited(loadSchedules());
            },
          ),
          const SizedBox(height: 8),
          const PatientDoctorArrivalInfo(),
          const SizedBox(height: 8),
          _ExpandablePatientDoctorBiography(
            key: ValueKey(('doctor-biography', doctorId)),
            text: doctor['tentangDokter'],
          ),
          if (selectedService?['modeReservasi'] == 'ANTREAN_HARIAN') ...[
            const MobileNotice(
              'Poliklinik ini menggunakan antrean harian, bukan booking slot dokter.',
            ),
            OutlinedButton.icon(
              onPressed: busy || loading
                  ? null
                  : () => setState(() {
                      bookingStage = doctorDetail = appointment = false;
                      doctorId = sessionId = slotId = null;
                    }),
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Daftar antrean poliklinik'),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: busy || loading ? null : load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Muat ulang jadwal'),
            ),
          ),
        ],
        if (selectedService != null && !appointment && !bookingStage) ...[
          const SizedBox(height: 16),
          TextField(
            controller: date,
            enabled: !busy && !loading,
            decoration: InputDecoration(
              labelText: 'Tanggal pelayanan',
              suffixIcon: IconButton(
                tooltip: 'Pilih tanggal pelayanan',
                onPressed: busy || loading
                    ? null
                    : () async {
                        final chosen = await showDatePicker(
                          context: context,
                          initialDate: initialServiceDate(
                            date.text,
                            widget.api.config.today,
                          ),
                          firstDate: DateTime.parse(widget.api.config.today),
                          lastDate: DateTime.parse(widget.api.config.today)
                              .add(const Duration(days: 365)),
                        );
                        if (chosen != null && mounted) {
                          setState(() => date.text = calendarDate(chosen));
                        }
                      },
                icon: const Icon(Icons.calendar_month),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const MobileNotice(
            'Walk-in mengikuti kuota harian poli. Bawa tiket QR pada tanggal pelayanan.',
          ),
        ],
        if (selectedService != null && !appointment && !bookingStage) ...[
          const SizedBox(height: 16),
          if (slotId != null)
            Text(
              'Tanggal terpilih: ${date.text}',
              style: const TextStyle(color: PatientDesign.darkTeal),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy || loading || (appointment && slotId == null)
                ? null
                : book,
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              busy
                  ? 'Memproses…'
                  : appointment
                  ? 'Lanjutkan'
                  : 'Reservasi walk-in',
            ),
          ),
        ],
      ],
    );
  }

  Widget _history(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PatientHeading(
        title: 'Riwayat kunjungan',
        onBack: () => setState(() => tab = 0),
      ),
      if (!tickets.any(
        (t) =>
            ['SELESAI', 'DIBATALKAN'].contains(t['status']) ||
            dateOnly(t['tanggalPelayanan'] ?? t['tanggalAntrean'])
                    .compareTo(widget.api.config.today) <
                0,
      ))
        const EmptyState(text: 'Belum ada riwayat kunjungan.'),
      for (final t in tickets.where(
        (t) =>
            ['SELESAI', 'DIBATALKAN'].contains(t['status']) ||
            dateOnly(t['tanggalPelayanan'] ?? t['tanggalAntrean'])
                    .compareTo(widget.api.config.today) <
                0,
      ))
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${t['nomorAntrean']} · ${label(object(t['layanan']))}',
            ),
            subtitle: Text(
              patientDate('${t['tanggalPelayanan'] ?? t['tanggalAntrean']}'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openTicket(t),
          ),
        ),
    ],
  );

  Widget _reservationHistory() => ValueListenableBuilder<PatientQueueState>(
    valueListenable: overviewCubit.queueState,
    builder: (context, queue, _) => ReservationList(
      items: patientReservations(
        tickets,
        appointments,
        doctors,
        widget.api.config.today,
      ),
      config: widget.api.config,
      loading: loading,
      busy: busy,
      error: error,
      message: message,
      queueState: queue,
      dataAvailable:
          patientVisitPaths.every(
            repository.snapshot.collections.containsKey,
          ) &&
          !repository.errors.keys.any(patientVisitPaths.contains),
      onRefresh: load,
      onCreate: createReservation,
      onTicket: (r) => openTicket(r.ticket, issueQrOnOpen: !r.terminal),
      onCancel: (r) => cancel(r.appointment!),
    ),
  );
}

/// Compact doctor biography. The existing DoctorBiography retains all of its
/// copy and fallback logic; only visibility is controlled locally.
class _ExpandablePatientDoctorBiography extends StatefulWidget {
  const _ExpandablePatientDoctorBiography({super.key, required this.text});

  final dynamic text;

  @override
  State<_ExpandablePatientDoctorBiography> createState() =>
      _ExpandablePatientDoctorBiographyState();
}

class _ExpandablePatientDoctorBiographyState
    extends State<_ExpandablePatientDoctorBiography> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: QueueBMotion.duration(context, QueueBMotion.component),
    alignment: Alignment.topCenter,
    curve: Curves.easeOutCubic,
    child: expanded
        ? Stack(
            children: [
              DoctorBiography(text: widget.text),
              Positioned(
                top: 0,
                right: 4,
                child: IconButton(
                  tooltip: 'Sembunyikan tentang dokter',
                  onPressed: () => setState(() => expanded = false),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
              ),
            ],
          )
        : Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: PatientDesign.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => expanded = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tentang Dokter',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PatientDesign.ink,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}

/// Read-only preview of upcoming practice sessions. The selected date is
/// owned by PatientPage; this widget owns only the visible month.
class _PatientDoctorSchedulePicker extends StatefulWidget {
  const _PatientDoctorSchedulePicker({
    super.key,
    required this.dates,
    required this.sessions,
    required this.value,
    required this.config,
    required this.enabled,
    required this.loading,
    this.showSessionDetails = true,
    this.footer,
    required this.onChanged,
  });

  final List<String> dates;
  final List<Json> sessions;
  final String value;
  final AppConfig config;
  final bool enabled, loading;
  final bool showSessionDetails;
  final Widget? footer;
  final ValueChanged<String> onChanged;

  @override
  State<_PatientDoctorSchedulePicker> createState() =>
      _PatientDoctorSchedulePickerState();
}

class _PatientDoctorSchedulePickerState
    extends State<_PatientDoctorSchedulePicker> {
  static const _months = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  static const _weekdays = <String>[
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  String? month;
  TextScaler? _lastTextScaler;
  final _daysController = ScrollController();

  String _monthOf(String day) => day.substring(0, 7);

  String _monthLabel(String value) {
    final parsed = DateTime.parse('$value-01');
    return '${_months[parsed.month - 1]} ${parsed.year}';
  }

  @override
  void initState() {
    super.initState();
    month = widget.value.length >= 7 ? _monthOf(widget.value) : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scaler = MediaQuery.textScalerOf(context);
    if (_lastTextScaler == scaler) return;
    _lastTextScaler = scaler;
    _revealSelectedDay();
  }

  @override
  void didUpdateWidget(covariant _PatientDoctorSchedulePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value.length >= 7) {
      month = _monthOf(widget.value);
    }
    if (widget.value != oldWidget.value ||
        widget.dates.length != oldWidget.dates.length) {
      _revealSelectedDay();
    }
  }

  void _revealSelectedDay() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_daysController.hasClients) return;
        final visible =
            widget.dates
                .toSet()
                .where((day) => day.length >= 7 && _monthOf(day) == month)
                .toList()
              ..sort();
        final index = visible.indexOf(widget.value);
        if (index < 0) return;
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final width = 60 * scale.clamp(1.0, double.infinity);
        _daysController.jumpTo(
          (index * (width + 8)).clamp(
            0.0,
            _daysController.position.maxScrollExtent,
          ),
        );
      });

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  Widget _scheduleCard(Widget child) => Card(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: PatientDesign.border),
    ),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final days = widget.dates.toSet().toList()..sort();
    final months = days.map(_monthOf).toSet().toList()..sort();
    if (months.isEmpty) {
      return _scheduleCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Jadwal praktik',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (widget.loading)
              const LinearProgressIndicator()
            else
              const Text(
                'Dokter belum memiliki jadwal praktik mendatang.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
          ],
        ),
      );
    }

    final chosenMonth = months.contains(month)
        ? month!
        : months.contains(
            widget.value.length >= 7 ? _monthOf(widget.value) : '',
          )
        ? _monthOf(widget.value)
        : months.first;
    final monthDays = days.where((d) => _monthOf(d) == chosenMonth).toList();
    final selectedDay = monthDays.contains(widget.value)
        ? widget.value
        : monthDays.first;
    final visibleSessions =
        widget.sessions
            .where((s) => dateOnly(s['tanggal']) == selectedDay)
            .toList()
          ..sort(
            (a, b) =>
                '${a['mulaiPada'] ?? ''}'.compareTo('${b['mulaiPada'] ?? ''}'),
          );
    final animation = QueueBMotion.duration(context, QueueBMotion.component);

    final textScaler = MediaQuery.textScalerOf(context);
    final textScale = textScaler.scale(14) / 14;
    final dayTileHeight =
        textScaler.scale(12) * 1.25 +
        textScaler.scale(22) * 1.2 +
        textScaler.scale(11) * 1.25 +
        24;
    return _scheduleCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: PatientDesign.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Jadwal Praktik',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Semantics(
                label: 'Pilih bulan jadwal praktik',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: PatientDesign.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 48,
                      maxWidth: 132 * textScale.clamp(1.0, double.infinity),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: chosenMonth,
                        isDense: false,
                        isExpanded: true,
                        itemHeight: null,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: [
                          for (final entry in months)
                            DropdownMenuItem(
                              value: entry,
                              child: Text(
                                _monthLabel(entry),
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                        ],
                        onChanged: !widget.enabled
                            ? null
                            : (next) {
                                if (next == null || next == chosenMonth) return;
                                final first = days.firstWhere(
                                  (day) => _monthOf(day) == next,
                                );
                                setState(() => month = next);
                                widget.onChanged(first);
                              },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: dayTileHeight,
            child: ListView.separated(
              controller: _daysController,
              scrollDirection: Axis.horizontal,
              itemCount: monthDays.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = monthDays[index];
                final parsed = DateTime.parse(day);
                final selected = day == selectedDay;
                return Semantics(
                  selected: selected,
                  label:
                      '${_weekdays[parsed.weekday - 1]}, ${patientDate(day)}',
                  child: SizedBox(
                    width: 60 * textScale.clamp(1.0, double.infinity),
                    child: OutlinedButton(
                      onPressed: !widget.enabled || selected
                          ? null
                          : () => widget.onChanged(day),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        backgroundColor: selected
                            ? PatientDesign.primary
                            : PatientDesign.soft,
                        disabledBackgroundColor: selected
                            ? PatientDesign.primary
                            : PatientDesign.soft,
                        foregroundColor: selected
                            ? Colors.white
                            : PatientDesign.ink,
                        disabledForegroundColor: selected
                            ? Colors.white
                            : PatientDesign.muted,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdays[parsed.weekday - 1],
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: selected
                                  ? Colors.white
                                  : PatientDesign.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${parsed.day}',
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : PatientDesign.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selected ? 'Terpilih' : 'Jadwal',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: selected
                                  ? Colors.white
                                  : PatientDesign.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: animation,
            switchInCurve: Curves.easeOutCubic,
            child: Column(
              key: ValueKey(('practice-date', selectedDay)),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.footer == null)
                  Text(
                    patientDate(selectedDay),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PatientDesign.navy,
                    ),
                  ),
                if (widget.showSessionDetails) ...[
                  const SizedBox(height: 8),
                  if (visibleSessions.isEmpty)
                    const Text('Belum ada sesi pada tanggal ini.')
                  else
                    for (final session in visibleSessions) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PatientDesign.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PatientInfoRow(
                              icon: Icons.schedule_outlined,
                              title: 'Waktu praktik',
                              value: patientTime(session, widget.config),
                            ),
                            const Divider(height: 12),
                            PatientInfoRow(
                              icon: Icons.room_outlined,
                              title: 'Ruang / Loket',
                              value: _roomLabel(object(session['loket'])),
                            ),
                          ],
                        ),
                      ),
                    ],
                ],
              ],
            ),
          ),
          if (widget.footer != null) widget.footer!,
        ],
      ),
    );
  }

  String _roomLabel(Json room) {
    if (room.isEmpty) return 'Belum ditentukan';
    final code = '${room['kode'] ?? ''}'.trim();
    final name = label(room).trim();
    if (code.isEmpty) return name.isEmpty ? 'Belum ditentukan' : name;
    return name.isEmpty || name == code ? code : '$code · $name';
  }
}

class PatientBranchView extends StatelessWidget {
  const PatientBranchView({
    super.key,
    required this.index,
    this.bookingView = false,
  });
  final int index;
  final bool bookingView;
  @override
  Widget build(BuildContext context) {
    final owner = context
        .dependOnInheritedWidgetOfExactType<_PatientViewScope>()!
        .owner;
    final branch = owner.widget.navigationShell?.currentIndex;
    final content = owner.branch(context, index, bookingView: bookingView);
    return PopScope(
      canPop: kIsWeb || !bookingView || !owner.busy,
      // Root destinations animate without remounting the indexed shell.
      // Booking/detail routes already use QueueBRouteMotion in app_router.dart.
      child: bookingView || branch == null
          ? content
          : PatientBranchReveal(active: branch == index, child: content),
    );
  }
}

class _PatientViewScope extends InheritedWidget {
  const _PatientViewScope({required this.owner, required super.child});
  final _PatientPageState owner;
  @override
  bool updateShouldNotify(_PatientViewScope oldWidget) => true;
}

/// Read-only destination. QR issuance remains an explicit, transient dialog action.
class PatientTicketRoute extends StatefulWidget {
  const PatientTicketRoute({super.key, required this.ticketId});
  final String ticketId;
  @override
  State<PatientTicketRoute> createState() => _PatientTicketRouteState();
}

class _PatientTicketRouteState extends State<PatientTicketRoute> {
  static const unavailable = 'Tiket tidak tersedia atau tidak dapat diakses.';
  PatientTicketCubit? controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context
        .dependOnInheritedWidgetOfExactType<_PatientViewScope>()!
        .owner;
    controller ??= PatientTicketCubit(owner.repository, widget.ticketId)
      ..refresh();
  }

  @override
  void dispose() {
    controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PatientTicketCubit, PatientTicketState>(
        bloc: controller!,
        builder: (context, state) {
          final ticket = controller!.ticket;
          final owner = context
              .dependOnInheritedWidgetOfExactType<_PatientViewScope>()!
              .owner;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Detail Tiket'),
              leading: BackButton(
                onPressed: () => context.go('/patient/tickets'),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.load == PatientLoad.loading ||
                    state.load == PatientLoad.initial)
                  const LinearProgressIndicator()
                else if (state.error != null || ticket == null)
                  Semantics(
                    label: unavailable,
                    excludeSemantics: true,
                    child: const MobileNotice(unavailable, error: true),
                  )
                else ...[
                  Text(
                    'Tiket ${ticket['nomorAntrean']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(label(object(ticket['layanan']))),
                  ReservationStatus('${ticket['status']}'),
                  FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      animationStyle: QueueBMotion.modalStyle(context),
                      builder: (_) => _TicketDialog(
                        api: owner.widget.api,
                        repository: owner.repository,
                        ticket: ticket,
                        controller: controller,
                        onManage: owner.showReservations,
                      ),
                    ),
                    child: const Text('Lihat tiket & QR'),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _TicketDialog extends StatefulWidget {
  const _TicketDialog({
    required this.api,
    required this.ticket,
    required this.repository,
    this.appointment,
    this.issueQrOnOpen = false,
    this.controller,
    this.onManage,
  });
  final QueueApi api;
  final Json ticket;
  final PatientRepository repository;
  final Json? appointment;
  final bool issueQrOnOpen;
  final PatientTicketCubit? controller;
  final VoidCallback? onManage;
  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  late final PatientTicketCubit controller;
  Json get data => controller.ticket ?? patientObject(widget.ticket);
  PatientQr? qr;
  String? get error => controller.state.error;
  bool get busy => controller.state.mutation == PatientMutation.submitting;
  bool get loading => [
    PatientLoad.initial,
    PatientLoad.loading,
    PatientLoad.refreshing,
  ].contains(controller.state.load);
  Timer? countdown;
  Timer? qrExpiry;
  int remaining = 0;
  bool get canIssue => controller.canIssue;
  @override
  void initState() {
    super.initState();
    controller =
        widget.controller ??
        PatientTicketCubit(widget.repository, '${widget.ticket['id']}');
    countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        remaining =
            qr?.expiresAt
                .difference(widget.api.config.now)
                .inSeconds
                .clamp(0, 600) ??
            0;
        if (remaining == 0 || !canIssue) {
          qr?.clear();
          qr = null;
        }
      });
    });
    if (widget.controller == null) initialize();
  }

  Future<void> initialize() async {
    await refresh();
    if (mounted && widget.issueQrOnOpen && error == null && canIssue) {
      await issue();
    }
  }

  Future<void> refresh() => controller.refresh();
  Future<void> issue() async {
    if (busy || loading || controller.state.dispatchLoading || !canIssue)
      return;
    setState(() {
      qrExpiry?.cancel();
      qr?.clear();
      qr = null;
    });
    PatientQr? result;
    try {
      result = await controller.issue();
    } catch (e) {
      if (mounted && widget.repository.active) {
        QueueBFeedback.error(context, '${patientError(e)}');
      }
      return;
    }
    if (!mounted || !canIssue) {
      result?.clear();
      return;
    }
    setState(() {
      qr = result;
      remaining =
          result?.expiresAt
              .difference(widget.api.config.now)
              .inSeconds
              .clamp(0, 600) ??
          0;
      if (remaining == 0) {
        qr?.clear();
        qr = null;
      } else if (result != null) {
        final lifetime = result.expiresAt.difference(widget.api.config.now);
        qrExpiry = Timer(
          lifetime > const Duration(minutes: 10)
              ? const Duration(minutes: 10)
              : lifetime,
          () {
            if (mounted) {
              setState(() {
                qr?.clear();
                qr = null;
                remaining = 0;
              });
            }
          },
        );
      }
    });
  }

  void changed(PatientTicketState state) {
    if (!canIssue) {
      qrExpiry?.cancel();
      setState(() {
        qr?.clear();
        qr = null;
        remaining = 0;
      });
    }
    if (state.load == PatientLoad.sessionEnded) {
      final route = ModalRoute.of(context);
      if (route?.isCurrent == true) {
        Navigator.of(context).pop();
      } else if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }
  }

  @override
  void dispose() {
    qr?.clear();
    qrExpiry?.cancel();
    countdown?.cancel();
    if (widget.controller == null) controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: controller,
    child: BlocConsumer<PatientTicketCubit, PatientTicketState>(
      bloc: controller,
      listener: (context, state) => changed(state),
      builder: (context, _) => content(context),
    ),
  );
  // QR issuance, expiry, and session cleanup remain owned by the existing
  // PatientTicketCubit. Only the visual presentation changes in V3.
  Widget _ticketFact(String title, String value) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 10, color: PatientDesign.muted),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: PatientDesign.ink,
        ),
      ),
    ],
  );

  Widget _qrNotice(IconData icon, String title, {String? detail}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: PatientDesign.soft.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: PatientDesign.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PatientDesign.ink,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: PatientDesign.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  bool exportingPdf = false;

  PatientTicketPdfData _pdfData(Json ticket) {
    final slot = object(widget.appointment?['slotPraktik']);
    final session = object(slot['jadwalPraktik']);
    final doctor = object(object(session['dokterLayanan'])['dokter']);
    final sessionRoom = object(session['loket']);
    final room = sessionRoom.isNotEmpty ? sessionRoom : object(ticket['ruang']);
    final code = '${room['kode'] ?? ''}'.trim();
    final name = label(room).trim();
    final roomLabel = code.isEmpty || code == name ? name : '$code · $name';
    final day = dateOnly(
      ticket['tanggalPelayanan'] ?? ticket['tanggalAntrean'],
    );
    return PatientTicketPdfData(
      queueNumber: '${ticket['nomorAntrean'] ?? '—'}',
      serviceName: label(object(ticket['layanan'])),
      status: reservationStatus('${ticket['status'] ?? ''}'),
      serviceDate: day.isEmpty ? 'Belum ditentukan' : patientDate(day),
      patientName: '${widget.api.user?['nama'] ?? ''}'.trim(),
      consultationTime: slot['mulaiPada'] == null
          ? null
          : '${patientTime(slot, widget.api.config)} · ${widget.api.config.serviceTimeZone}',
      doctorName: doctor['nama'] == null ? null : label(doctor),
      roomName: room.isEmpty || roomLabel.isEmpty ? null : roomLabel,
      // A deep link can omit appointment details; do not infer walk-in then.
      reservationCode: '${ticket['kodeTiket'] ?? ''}',
      reservationType: widget.appointment != null
          ? 'Janji temu dokter'
          : object(ticket['layanan'])['modeReservasi'] == 'ANTREAN_HARIAN'
          ? 'Antrean harian / Walk-in'
          : null,
    );
  }

  Future<void> _exportPdf({required bool print}) async {
    if (exportingPdf ||
        busy ||
        loading ||
        error != null ||
        !widget.repository.active ||
        controller.state.load != PatientLoad.loaded ||
        controller.ticket == null ||
        const {'MENUNGGU', 'DILAYANI'}.contains(controller.ticket?['status'])) {
      return;
    }
    // Only the successfully refreshed, owned ticket is exported. Never rely
    // on the potentially stale snapshot supplied to this dialog.
    final selected = _pdfData(controller.ticket!);
    setState(() => exportingPdf = true);
    try {
      if (print) {
        await PatientTicketPdf.print(selected);
      } else {
        await PatientTicketPdf.save(selected);
      }
      // A system dialog can be dismissed. Do not claim printing succeeded.
    } catch (_) {
      if (!mounted) return;
      QueueBFeedback.error(
        context,
        print
            ? 'Dialog cetak tidak dapat dibuka. Coba kembali.'
            : 'PDF belum dapat disimpan. Coba kembali.',
      );
    } finally {
      if (mounted) setState(() => exportingPdf = false);
    }
  }

  void _closeTicket() {
    if (!busy && mounted) Navigator.of(context).pop();
  }

  void _manageTicket() {
    final onManage = widget.onManage;
    if (onManage == null || busy || loading || error != null) return;
    Navigator.of(context).pop();
    onManage();
  }

  String _ticketClock(DateTime? instant) => instant == null
      ? '—'
      : '${clockOnly(widget.api.config.localInput(instant.toIso8601String())).replaceAll(':', '.')} '
            '${patientHomeTimeZone(widget.api.config.serviceTimeZone)}';

  Widget _ticketIdentity({
    required Json ticket,
    required String service,
    required String dateLabel,
    required String destination,
    required String checkedInLabel,
  }) {
    final status = '${ticket['status'] ?? '—'}';
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOMOR REGISTRASI',
          style: TextStyle(
            fontSize: 10,
            height: 1.3,
            letterSpacing: .5,
            fontWeight: FontWeight.w600,
            color: PatientDesign.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${ticket['nomorAntrean'] ?? '—'}',
          style: const TextStyle(
            fontSize: 32,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
            fontFeatures: [FontFeature.tabularFigures()],
            color: PatientDesign.primary,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: PatientDesign.soft,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Layanan: $service',
            style: const TextStyle(
              fontSize: 10,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: PatientDesign.muted,
            ),
          ),
        ),
      ],
    );
    final state = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ReservationStatus(status),
        if (checkedInLabel != '—') ...[
          const SizedBox(height: 4),
          const Text(
            'Check-in',
            style: TextStyle(fontSize: 10, color: PatientDesign.muted),
          ),
          const SizedBox(height: 2),
          Text(
            checkedInLabel,
            style: const TextStyle(
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
              color: PatientDesign.ink,
            ),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, bounds) {
            if (bounds.maxWidth < 270 ||
                MediaQuery.textScalerOf(context).scale(12) > 17) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 6), state],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 6),
                Flexible(child: state),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PatientDesign.soft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final normalText =
                  MediaQuery.textScalerOf(context).scale(12) <= 17;
              final columns = normalText && bounds.maxWidth >= 264
                  ? 3
                  : normalText && bounds.maxWidth >= 220
                  ? 2
                  : 1;
              final facts = <(String, String)>[
                ('Pasien', '${widget.api.user?['nama'] ?? '—'}'),
                ('Tanggal', dateLabel),
                ('Loket Tujuan', destination),
              ];
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final fact in facts)
                    SizedBox(
                      width: (bounds.maxWidth - (columns - 1) * 6) / columns,
                      child: _ticketFact(fact.$1, fact.$2),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _proofQr(String payload, String title, {String? subtitle}) =>
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: PatientDesign.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PatientDesign.ink,
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, box) => QrImageView(
                data: payload,
                size: box.maxWidth.clamp(0.0, 208.0),
                padding: const EdgeInsets.all(12),
                backgroundColor: Colors.white,
                semanticsLabel: '$title tiket ${data['nomorAntrean']}',
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: PatientDesign.muted,
                ),
              ),
          ],
        ),
      );

  Widget _temporaryCheckInQr(String day, String dayLabel) => ExpansionTile(
    key: const PageStorageKey('ticket-temporary-check-in-qr'),
    dense: true,
    minTileHeight: 44,
    expansionAnimationStyle: AnimationStyle(
      duration: QueueBMotion.duration(context, QueueBMotion.component),
      reverseDuration: QueueBMotion.duration(context, QueueBMotion.component),
    ),
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
    initiallyExpanded: widget.issueQrOnOpen,
    shape: const Border(),
    collapsedShape: const Border(),
    leading: const Icon(Icons.qr_code_2_rounded, size: 18),
    title: const Text(
      'QR Check-in Sementara',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    subtitle: const Text(
      'Kode sekali pakai untuk check-in pada hari pelayanan.',
      style: TextStyle(fontSize: 11, height: 1.3),
    ),
    children: [
      if (qr?.payload != null && remaining > 0 && canIssue)
        _proofQr(
          qr!.payload!,
          'QR Check-in Sementara',
          subtitle: 'Berlaku $remaining detik · sekali pakai',
        )
      else if (day.compareTo(widget.api.config.today) > 0)
        _qrNotice(
          Icons.event_available_outlined,
          'QR check-in tersedia pada $dayLabel',
          detail: 'QR bukti reservasi di atas tetap terpisah.',
        )
      else if (canIssue)
        _qrNotice(
          Icons.qr_code_2_rounded,
          'QR check-in siap diterbitkan',
          detail: 'Kode sementara berlaku 10 menit dan sekali pakai.',
        )
      else
        _qrNotice(
          Icons.event_busy_outlined,
          'QR check-in belum tersedia',
          detail: 'Periksa tanggal pelayanan dan muat ulang status tiket.',
        ),
      if (canIssue) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || loading || controller.state.dispatchLoading
                ? null
                : issue,
            style: _ticketActionStyle(primary: true),
            icon: const Icon(Icons.qr_code_rounded, size: 18),
            label: Text(qr == null ? 'Terbitkan QR' : 'Perbarui QR'),
          ),
        ),
      ],
    ],
  );

  ButtonStyle _ticketActionStyle({bool primary = false}) =>
      FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        backgroundColor: primary ? PatientDesign.primary : PatientDesign.soft,
        foregroundColor: primary ? Colors.white : PatientDesign.ink,
        textStyle: const TextStyle(
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _ticketExportActions() => LayoutBuilder(
    builder: (context, bounds) {
      final disabled =
          exportingPdf ||
          busy ||
          loading ||
          error != null ||
          !widget.repository.active ||
          controller.state.load != PatientLoad.loaded ||
          controller.ticket == null;
      final download = FilledButton.icon(
        onPressed: disabled ? null : () => _exportPdf(print: false),
        style: _ticketActionStyle(),
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('Unduh PDF'),
      );
      final print = FilledButton.icon(
        onPressed: disabled ? null : () => _exportPdf(print: true),
        style: _ticketActionStyle(),
        icon: const Icon(Icons.print_outlined, size: 18),
        label: const Text('Cetak Tiket'),
      );
      if (bounds.maxWidth < 270 ||
          MediaQuery.textScalerOf(context).scale(12) > 17) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [download, const SizedBox(height: 8), print],
        );
      }
      return Row(
        children: [
          Expanded(child: download),
          const SizedBox(width: 8),
          Expanded(child: print),
        ],
      );
    },
  );

  Widget _ticketFooter(bool waiting) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: busy || loading || controller.state.dispatchLoading
            ? null
            : refresh,
        style: _ticketActionStyle(primary: true),
        icon: const Icon(Icons.sync_rounded, size: 16),
        label: Text(waiting ? 'Perbarui Status' : 'Perbarui'),
      ),
      const SizedBox(height: 4),
      LayoutBuilder(
        builder: (context, bounds) {
          final manage = FilledButton.icon(
            onPressed:
                widget.onManage == null ||
                    busy ||
                    loading ||
                    error != null ||
                    !widget.repository.active ||
                    controller.ticket == null
                ? null
                : _manageTicket,
            style: _ticketActionStyle(),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Kelola'),
          );
          final close = FilledButton(
            onPressed: busy ? null : _closeTicket,
            style: _ticketActionStyle(),
            child: const Text('Tutup'),
          );
          if (bounds.maxWidth < 220 ||
              MediaQuery.textScalerOf(context).scale(13) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [manage, const SizedBox(height: 4), close],
            );
          }
          return Row(
            children: [
              Expanded(child: manage),
              const SizedBox(width: 6),
              Expanded(child: close),
            ],
          );
        },
      ),
    ],
  );

  Widget content(BuildContext context) {
    final currentTicket = data;
    final state = controller.state;
    final status = '${currentTicket['status'] ?? '—'}';
    final waiting = status == 'MENUNGGU';
    final booked = status == 'DIPESAN';
    final day = dateOnly(
      currentTicket['tanggalPelayanan'] ?? currentTicket['tanggalAntrean'],
    );
    final parsedDay = DateTime.tryParse(day);
    final dateLabel = parsedDay == null
        ? 'Belum ditentukan'
        : '${patientCompactDate(day)} ${parsedDay.year}';
    final dispatch = state.dispatch;
    final sameTicket = dispatch?.matches(currentTicket) == true;
    final verifiedDispatch = sameTicket ? dispatch : null;
    final currentDispatch =
        verifiedDispatch != null &&
        verifiedDispatch.freshAt(widget.api.config.now) &&
        error == null &&
        state.load == PatientLoad.loaded &&
        widget.repository.active &&
        !state.dispatchLoading &&
        state.dispatchError == null;
    final slot = object(widget.appointment?['slotPraktik']);
    final session = object(slot['jadwalPraktik']);
    final doctor = object(object(session['dokterLayanan'])['dokter']);
    final assigned = currentDispatch
        ? object(verifiedDispatch?.destination)
        : <String, dynamic>{};
    final scheduled = object(session['loket']);
    // A waiting ticket's check-in room is not its promised CALL destination.
    final room = assigned.isNotEmpty
        ? assigned
        : booked
        ? scheduled
        : <String, dynamic>{};
    final roomCode = '${room['kode'] ?? ''}'.trim();
    final roomText = roomCode.isNotEmpty
        ? roomCode
        : room.isEmpty
        ? 'Belum ditetapkan'
        : label(room);
    final checkedIn = verifiedDispatch?.checkedInAt;
    final receipt =
        booked &&
            error == null &&
            state.load == PatientLoad.loaded &&
            controller.ticket != null
        ? _pdfData(controller.ticket!).receiptQrPayload
        : null;
    final service = label(object(currentTicket['layanan']));
    final statusDescription = switch (status) {
      'CHECK_IN' =>
        'Check-in tercatat. Menunggu pembaruan antrean dari petugas.',
      'DIPANGGIL' => 'Nomor Anda sedang dipanggil. Perhatikan loket tujuan dan panggilan petugas.',
      'DILAYANI' => 'Pelayanan sedang berlangsung.',
      'SELESAI' => 'Pelayanan selesai.',
      'DIBATALKAN' => 'Reservasi telah dibatalkan.',
      'DILEWATI' => 'Panggilan dilewati. Hubungi petugas untuk tindak lanjut.',
      _ => 'Status tiket: ${reservationStatus(status)}.',
    };
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ticketIdentity(
          ticket: currentTicket,
          service: service,
          dateLabel: dateLabel,
          destination: roomText,
          checkedInLabel: _ticketClock(checkedIn),
        ),
        if (slot['mulaiPada'] != null || doctor['nama'] != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (slot['mulaiPada'] != null)
                Text(
                  '${patientTime(slot, widget.api.config)} '
                  '${patientHomeTimeZone(widget.api.config.serviceTimeZone)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: PatientDesign.muted,
                  ),
                ),
              if (doctor['nama'] != null)
                Text(
                  label(doctor),
                  style: const TextStyle(
                    fontSize: 11,
                    color: PatientDesign.muted,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        const PatientTicketSeparator(),
        const SizedBox(height: 4),
        if (loading || busy) ...[
          const LinearProgressIndicator(semanticsLabel: 'Memuat tiket'),
          const SizedBox(height: 8),
        ],
        if (error != null) ...[
          MobileNotice(error!, error: true),
          const SizedBox(height: 8),
        ],
        if (waiting) ...[
          PatientTicketDispatchPanel(
            position: currentDispatch ? verifiedDispatch?.position : null,
            ahead: currentDispatch ? verifiedDispatch?.ahead : null,
            serving: currentDispatch
                ? verifiedDispatch?.serving ?? const []
                : const [],
            checkInLabel: _ticketClock(checkedIn),
            checkInVerified: checkedIn != null,
            loading: state.dispatchLoading,
            failed: state.dispatchError != null || error != null,
            live: currentDispatch && state.dispatchConnected,
            updatedLabel: verifiedDispatch == null
                ? null
                : _ticketClock(verifiedDispatch.observedAt),
          ),
          if (state.dispatchError != null) ...[
            const SizedBox(height: 6),
            const Text(
              'Status antrean belum dapat diperbarui. Coba Perbarui Status.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: PatientDesign.muted,
              ),
            ),
          ],
        ] else if (booked) ...[
          if (receipt != null)
            _proofQr(
              receipt,
              'QR Bukti Reservasi',
              subtitle: 'Simpan atau tunjukkan bukti reservasi sesuai alur pelayanan.',
            )
          else
            _qrNotice(
              Icons.receipt_long_outlined,
              'Bukti QR reservasi belum tersedia',
              detail: 'Perbarui tiket untuk memuat bukti reservasi yang sah.',
            ),
          const SizedBox(height: 8),
          _ticketExportActions(),
          const SizedBox(height: 4),
          _temporaryCheckInQr(day, dateLabel),
        ] else ...[
          _qrNotice(
            PatientDesign.statusIcon(status),
            reservationStatus(status),
            detail: statusDescription,
          ),
          if (status != 'DILAYANI') ...[
            if (checkedIn != null) ...[
              const SizedBox(height: 8),
              _ticketFact('Check-in terverifikasi', _ticketClock(checkedIn)),
            ],
            const SizedBox(height: 8),
            _ticketExportActions(),
          ],
        ],
        if (exportingPdf && status != 'MENUNGGU' && status != 'DILAYANI') ...[
          const SizedBox(height: 6),
          const LinearProgressIndicator(semanticsLabel: 'Menyiapkan PDF tiket'),
        ],
      ],
    );
    return PopScope(
      canPop: !busy,
      child: Dialog(
        backgroundColor: PatientDesign.paper,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 4, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: PatientDesign.soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.confirmation_number_outlined,
                        size: 16,
                        color: PatientDesign.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Detail Tiket',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup detail tiket',
                      onPressed: busy ? null : _closeTicket,
                      style: IconButton.styleFrom(
                        backgroundColor: PatientDesign.soft,
                        foregroundColor: PatientDesign.muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                  child: body,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _ticketFooter(waiting),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
