import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api.dart';
import '../../config.dart';
import '../shared/safe_snapshot.dart';

class InsightsState {
  const InsightsState({
    this.data,
    this.loading = false,
    this.ended = false,
    this.error,
  });
  final Json? data;
  final bool loading, ended;
  final String? error;
}

/// The feature owns results; QueueApi retains authentication/session authority.
class InsightsCubit extends Cubit<InsightsState> {
  InsightsCubit(this.api)
    : identity = (api.user?['id'], api.user?['peran']),
      super(const InsightsState()) {
    api.addListener(_sessionChanged);
  }
  final QueueApi api;
  final (Object?, Object?) identity;
  int epoch = 0;
  bool get active =>
      !isClosed &&
      !state.ended &&
      api.sessionPhase == SessionPhase.ready &&
      identity == (api.user?['id'], api.user?['peran']) &&
      api.user?['peran'] == 'ADMIN';
  void _sessionChanged() {
    if (active || isClosed) return;
    epoch++;
    emit(const InsightsState(ended: true));
  }

  Future<void> load(String path, Map<String, String> query) async {
    if (!active) return;
    final current = ++epoch;
    emit(const InsightsState(loading: true));
    try {
      final raw = await api.request('GET', path, query: Map.of(query));
      if (!active || current != epoch) return;
      if (raw is! Map ||
          (path == '/audit-sesi'
              ? raw['data'] is! List || raw['total'] is! int
              : raw['baris'] is! List || raw['ringkasan'] is! Map)) {
        throw const ApiException(0, 'Respons belum dapat diverifikasi.');
      }
      emit(InsightsState(data: safeSnapshot(raw) as Json));
    } catch (error) {
      if (active && current == epoch) {
        emit(
          InsightsState(
            error: error is ApiException && error.status == 400
                ? error.message
                : 'Data belum dapat dimuat. Periksa periode dan muat ulang. Maksimal 31 hari per permintaan.',
          ),
        );
      }
    }
  }

  void invalidate() {
    if (!active) return;
    epoch++;
    emit(const InsightsState());
  }

  @override
  Future<void> close() {
    epoch++;
    api.removeListener(_sessionChanged);
    return super.close();
  }
}
