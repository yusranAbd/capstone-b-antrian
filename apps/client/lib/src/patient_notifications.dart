import 'dart:async';

import 'package:flutter/material.dart';

import 'queueb_feedback.dart';

import 'api.dart';
import 'config.dart';
import 'features/patient/data/patient_repository.dart';
import 'patient_sync.dart';

/// Own REST inbox, sharing the existing patient feed and session scope.
class PatientNotificationsDialog extends StatefulWidget {
  const PatientNotificationsDialog({super.key, required this.repository});
  final PatientRepository repository;
  @override
  State<PatientNotificationsDialog> createState() =>
      _PatientNotificationsDialogState();
}

class _PatientNotificationsDialogState
    extends State<PatientNotificationsDialog> {
  late final gate = RefreshGate(_read);
  PatientRepository get repository => widget.repository;
  Json? snapshot;
  String? error;
  bool loading = false, writing = false;
  int page = 1, epoch = 0;
  @override
  void initState() {
    super.initState();
    repository.api.addListener(_sessionChanged);
    repository.updates.addListener(_invalidated);
    unawaited(gate.refresh());
  }

  void _sessionChanged() {
    if (repository.active || !mounted) return;
    epoch++;
    setState(() {
      snapshot = null;
      error = 'Sesi pasien berakhir.';
    });
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      scheduleMicrotask(() {
        if (mounted && route.isActive) Navigator.of(context).removeRoute(route);
      });
    }
  }

  void _invalidated() {
    if (repository.updates.lastKinds.contains('TIKET')) {
      unawaited(gate.refresh());
    }
  }

  Future<void> _read() async {
    if (!mounted || !repository.active) return;
    final current = ++epoch, requestedPage = page;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = await repository.api.request(
        'GET',
        '/notifikasi/saya',
        query: {'halaman': '$requestedPage'},
      );
      if (!mounted || !repository.active || current != epoch) return;
      if (raw is! Map ||
          raw['data'] is! List ||
          raw['belumDibaca'] is! int ||
          raw['jumlahHalaman'] is! int) {
        throw const ApiException(
          0,
          'Respons notifikasi belum dapat diverifikasi.',
        );
      }
      if (requestedPage > (raw['jumlahHalaman'] as int) && requestedPage > 1) {
        page = raw['jumlahHalaman'] as int;
        unawaited(gate.refresh());
        return;
      }
      setState(() => snapshot = object(raw));
    } catch (_) {
      if (mounted && current == epoch) {
        setState(() {
          snapshot = null;
          error = 'Notifikasi belum dapat dimuat. Silakan muat ulang.';
        });
      }
    } finally {
      if (mounted && current == epoch) setState(() => loading = false);
    }
  }

  Future<void> markRead(Json row) async {
    if (writing || !repository.active || row['dibacaPada'] != null) return;
    setState(() => writing = true);
    try {
      await repository.api.request(
        'PATCH',
        '/notifikasi/${Uri.encodeComponent('${row['id']}')}/baca',
      );
      await gate.refresh();
    } catch (_) {
      if (mounted && repository.active) {
        setState(
          () => error =
              'Status baca belum dapat dipastikan. Muat ulang notifikasi.',
        );
      }
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  @override
  void dispose() {
    epoch++;
    gate.dispose();
    repository.api.removeListener(_sessionChanged);
    repository.updates.removeListener(_invalidated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Notifikasi'),
    content: SizedBox(
      width: 560,
      height: MediaQuery.sizeOf(context).height * .58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading || writing) const LinearProgressIndicator(),
          if (snapshot != null)
            Text('${snapshot!['belumDibaca']} belum dibaca'),
          if (error != null)
            QueueBPopupNotice(error!, kind: QueueBFeedbackKind.error),
          Expanded(
            child: snapshot == null
                ? const SizedBox.shrink()
                : rows(snapshot!['data']).isEmpty
                ? const Center(child: Text('Belum ada notifikasi.'))
                : ListView.separated(
                    itemCount: rows(snapshot!['data']).length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final row = rows(snapshot!['data'])[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          row['jenis'] == 'PEMANGGILAN'
                              ? Icons.campaign_outlined
                              : Icons.notifications_outlined,
                        ),
                        title: Text(
                          '${row['judul']}',
                          style: TextStyle(
                            fontWeight: row['dibacaPada'] == null
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        subtitle: Text(
                          '${row['pesan']}\n${repository.api.config.instantLabel(row['dibuatPada'])}',
                        ),
                        trailing: row['dibacaPada'] == null
                            ? IconButton(
                                tooltip: 'Tandai dibaca',
                                onPressed: writing ? null : () => markRead(row),
                                icon: const Icon(Icons.done),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          if (snapshot != null)
            Row(
              children: [
                Expanded(
                  child: Text('Halaman $page/${snapshot!['jumlahHalaman']}'),
                ),
                IconButton(
                  tooltip: 'Sebelumnya',
                  onPressed: loading || writing || page <= 1
                      ? null
                      : () {
                          setState(() {
                            page--;
                            snapshot = null;
                          });
                          unawaited(gate.refresh());
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Berikutnya',
                  onPressed:
                      loading ||
                          writing ||
                          page >= (snapshot!['jumlahHalaman'] as int)
                      ? null
                      : () {
                          setState(() {
                            page++;
                            snapshot = null;
                          });
                          unawaited(gate.refresh());
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading || writing || !repository.active
            ? null
            : () => gate.refresh(),
        child: const Text('Muat ulang'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  );
}
