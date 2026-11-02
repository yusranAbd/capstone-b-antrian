import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'admin_ui.dart';
import 'admin_schedules.dart' show AdminNotice;
import 'api.dart';
import 'config.dart';
import 'features/admin/data/admin_catalog_repository.dart';
import 'features/insights/insights_cubit.dart';
import 'operational_report_export.dart';
import 'routing/route_policy.dart';

const auditActionLabels = {
  'LOGIN': 'Login',
  'REFRESH': 'Refresh',
  'LOGOUT': 'Logout',
  'CABUT_SESI': 'Pencabutan sesi',
  'BACA_AUDIT': 'Pembacaan audit',
};
const auditResultLabels = {
  'BERHASIL': 'Berhasil',
  'DITOLAK': 'Ditolak',
  'ERROR': 'Error',
};

class AdminInsightsPage extends StatefulWidget {
  const AdminInsightsPage({
    super.key,
    required this.api,
    required this.catalog,
    this.audit = false,
  });
  final QueueApi api;
  final AdminCatalogRepository catalog;
  final bool audit;
  @override
  State<AdminInsightsPage> createState() => _AdminInsightsPageState();
}

class _AdminInsightsPageState extends State<AdminInsightsPage> {
  late final controller = InsightsCubit(widget.api);
  late final start = TextEditingController(
    text: widget.audit
        ? calendarDate(DateTime.now().toUtc())
        : widget.api.config.today,
  );
  late final end = TextEditingController(text: start.text);
  final accountRef = TextEditingController(),
      sessionRef = TextEditingController();
  String? serviceId, action, result, localError, feedback;
  int page = 1;
  bool exporting = false;
  DialogRoute<void>? detailRoute;
  NavigatorState? detailNavigator;
  @override
  void initState() {
    super.initState();
    widget.api.addListener(_scopeChanged);
    unawaited(load());
    if (!widget.audit) unawaited(_catalog());
  }

  void _scopeChanged() {
    if (!controller.active) _closeDetail();
  }

  void _closeDetail() {
    final route = detailRoute, navigator = detailNavigator;
    detailRoute = null;
    if (route == null) return;
    scheduleMicrotask(() {
      if (navigator != null && navigator.mounted && route.isActive) {
        navigator.removeRoute(route);
      }
    });
  }

  Future<void> _catalog() async {
    try {
      await widget.catalog.refresh(['/layanan']);
    } catch (_) {
      if (mounted && controller.active) {
        setState(
          () => localError =
              'Daftar layanan belum dapat dimuat. Muat ulang halaman.',
        );
      }
    }
  }

  void changed(VoidCallback update) {
    setState(() {
      update();
      page = 1;
      localError = null;
      feedback = null;
    });
    controller.invalidate();
  }

  Future<void> load() async {
    if (!controller.active) return;
    if (widget.audit &&
        [
          accountRef.text.trim(),
          sessionRef.text.trim(),
        ].any((v) => v.isNotEmpty && !RoutePolicy.validId(v))) {
      setState(
        () => localError =
            'Gunakan ID korelasi UUID lengkap dari detail aktivitas.',
      );
      return;
    }
    setState(() {
      localError = null;
      feedback = null;
    });
    await controller.load(
      widget.audit ? '/audit-sesi' : '/laporan/operasional',
      {
        'mulai': start.text,
        'selesai': end.text,
        if (serviceId != null && !widget.audit) 'layananId': serviceId!,
        if (widget.audit) ...{
          'halaman': '$page',
          'aksi': ?action,
          'hasil': ?result,
          if (accountRef.text.trim().isNotEmpty)
            'akunRef': accountRef.text.trim(),
          if (sessionRef.text.trim().isNotEmpty)
            'sesiRef': sessionRef.text.trim(),
        },
      },
    );
    if (!mounted || !controller.active) return;
    final max = controller.state.data?['jumlahHalaman'];
    if (widget.audit && max is int && page > max && page > 1) {
      setState(() => page = max);
      await load();
    }
  }

  Future<void> pickDate(TextEditingController field) async {
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(field.text),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (mounted && controller.active && value != null) {
      changed(() => field.text = calendarDate(value));
    }
  }

  Future<void> export(bool pdf) async {
    final snapshot = controller.state.data;
    if (snapshot == null || exporting || !controller.active) return;
    bool current() =>
        mounted &&
        controller.active &&
        identical(controller.state.data, snapshot);
    setState(() {
      exporting = true;
      feedback = null;
      localError = null;
    });
    try {
      final saved = pdf
          ? await shareOperationalPdf(snapshot, current: current)
          : await saveOperationalCsv(snapshot, current: current);
      if (current() && saved) {
        setState(
          () => feedback =
              'Laporan telah diserahkan ke dialog simpan/unduh perangkat.',
        );
      }
    } catch (error) {
      if (current()) {
        setState(
          () => localError = error is FormatException
              ? error.message
              : 'Laporan belum dapat diekspor. Silakan coba kembali.',
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  void dispose() {
    widget.api.removeListener(_scopeChanged);
    _closeDetail();
    unawaited(controller.close());
    start.dispose();
    end.dispose();
    accountRef.dispose();
    sessionRef.dispose();
    super.dispose();
  }

  Widget dateInput(String label, TextEditingController value, bool locked) =>
      SizedBox(
        width: 180,
        child: TextField(
          controller: value,
          readOnly: true,
          onTap: locked ? null : () => pickDate(value),
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
        ),
      );
  Widget choice(
    String label,
    String? value,
    Map<String, String> items,
    ValueChanged<String?> update,
    bool locked,
  ) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Semua')),
        if (value != null && !items.containsKey(value))
          DropdownMenuItem(
            value: value,
            child: const Text('Layanan tidak tersedia'),
          ),
        for (final e in items.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: locked
          ? null
          : (v) => changed(() => update(v == '' ? null : v)),
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<InsightsCubit, InsightsState>(
    bloc: controller,
    builder: (context, state) => state.ended
        ? const SizedBox.shrink()
        : ListenableBuilder(
            listenable: widget.catalog,
            builder: (context, _) {
              final locked = state.loading || exporting;
              final services = {
                for (final row
                    in widget.catalog.snapshot.collections['/layanan'] ??
                        <Json>[])
                  '${row['id']}': '${row['nama']}',
              };
              final snapshot = state.data;
              return ListView(
                padding: AdminStyle.pageInsets(context),
                children: [
                  AdminPageHeading(
                    title: widget.audit
                        ? 'Aktivitas akun dan sesi'
                        : 'Laporan operasional',
                    subtitle: widget.audit
                        ? 'Telusuri aktivitas autentikasi dan perubahan sesi akun.'
                        : 'Evaluasi layanan berdasarkan data operasional yang tersimpan.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      dateInput(
                        widget.audit ? 'Mulai (UTC)' : 'Mulai',
                        start,
                        locked,
                      ),
                      dateInput(
                        widget.audit ? 'Selesai (UTC)' : 'Selesai',
                        end,
                        locked,
                      ),
                      if (widget.audit) ...[
                        choice(
                          'Aktivitas',
                          action,
                          auditActionLabels,
                          (v) => action = v,
                          locked,
                        ),
                        choice(
                          'Hasil',
                          result,
                          auditResultLabels,
                          (v) => result = v,
                          locked,
                        ),
                      ] else
                        choice(
                          'Layanan',
                          serviceId,
                          services,
                          (v) => serviceId = v,
                          locked,
                        ),
                      FilledButton.icon(
                        onPressed: locked ? null : load,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Tampilkan'),
                      ),
                      if (!widget.audit) ...[
                        OutlinedButton.icon(
                          onPressed: locked || snapshot == null
                              ? null
                              : () => export(true),
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text('Ekspor PDF'),
                        ),
                        Tooltip(
                          message: reportCsvSupported
                              ? 'Ekspor seluruh hasil filter'
                              : 'CSV tersedia pada Web dan desktop',
                          child: OutlinedButton.icon(
                            onPressed:
                                locked ||
                                    snapshot == null ||
                                    !reportCsvSupported
                                ? null
                                : () => export(false),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: const Text('Ekspor CSV'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.audit) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: accountRef,
                            enabled: !locked,
                            maxLength: 36,
                            decoration: const InputDecoration(
                              labelText: 'Korelasi akun',
                              counterText: '',
                            ),
                            onChanged: (_) => changed(() {}),
                          ),
                        ),
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: sessionRef,
                            enabled: !locked,
                            maxLength: 36,
                            decoration: const InputDecoration(
                              labelText: 'Korelasi sesi',
                              counterText: '',
                            ),
                            onChanged: (_) => changed(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    widget.audit
                        ? 'Retensi 30 hari. Periode dan timestamp audit menggunakan UTC. Label klien merupakan klaim yang belum diverifikasi; asal proses tetap UNKNOWN. Histori sebelum aktivasi audit tidak direkonstruksi.'
                        : 'Maksimal 31 hari. Status adalah kondisi tiket saat laporan diambil. Tunggu dihitung sejak check-in sampai pelayanan dimulai; pelayanan sejak mulai sampai selesai. Durasi hanya memakai timestamp lengkap dan nonnegatif. PDF maksimal 500 baris; gunakan CSV atau persempit filter untuk laporan lebih besar.',
                  ),
                  if (locked)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: LinearProgressIndicator(),
                    ),
                  if (state.error != null || localError != null)
                    AdminNotice(localError ?? state.error!, error: true),
                  if (feedback != null) AdminNotice(feedback!, success: true),
                  if (snapshot != null) ...[
                    const SizedBox(height: 12),
                    if (widget.audit)
                      ...auditView(snapshot, locked)
                    else
                      ...reportView(snapshot),
                  ],
                ],
              );
            },
          ),
  );
  List<Widget> reportView(Json snapshot) {
    final summary = object(snapshot['ringkasan']);
    return [
      Text(
        'Diperoleh: ${widget.api.config.instantLabel(snapshot['diperolehPada'])} · ${object(snapshot['periode'])['zonaWaktu']}',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final e in reportStatusColumns.entries)
            Text('${e.value}: ${summary[e.key] ?? '—'}'),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Rata-rata tunggu: ${reportMinutes(summary['rataTungguDetik'])} menit (${summary['sampelTunggu']} sampel) · Pelayanan: ${reportMinutes(summary['rataPelayananDetik'])} menit (${summary['sampelPelayanan']} sampel)',
      ),
      const Text(
        'Pasien unik periode dihitung langsung; angka per tanggal/layanan tidak dijumlahkan menjadi pasien unik periode.',
      ),
      const SizedBox(height: 12),
      if (rows(snapshot['baris']).isEmpty)
        const Text('Tidak ada tiket pada periode dan filter ini.')
      else
        AdminTable(
          key: ObjectKey(snapshot),
          rows: rows(snapshot['baris']),
          numberedPagination: true,
          pageSize: 20,
          columns: [
            AdminColumn('Tanggal', (r) => r['tanggal']),
            AdminColumn('Layanan', (r) => r['namaLayanan']),
            for (final e in reportStatusColumns.entries)
              AdminColumn(e.value, (r) => r[e.key], numeric: true),
            AdminColumn(
              'Tunggu (menit)',
              (r) => reportMinutes(r['rataTungguDetik']),
            ),
            AdminColumn(
              'Sampel tunggu',
              (r) => r['sampelTunggu'],
              numeric: true,
            ),
            AdminColumn(
              'Pelayanan (menit)',
              (r) => reportMinutes(r['rataPelayananDetik']),
            ),
            AdminColumn(
              'Sampel pelayanan',
              (r) => r['sampelPelayanan'],
              numeric: true,
            ),
          ],
        ),
    ];
  }

  List<Widget> auditView(Json snapshot, bool locked) => [
    Text('${snapshot['total']} aktivitas cocok dengan filter'),
    if (rows(snapshot['data']).isEmpty)
      const Text('Tidak ada aktivitas pada periode dan filter ini.')
    else
      AdminTable(
        key: ObjectKey(snapshot),
        rows: rows(snapshot['data']),
        pageSize: 30,
        hideFooterWhenSinglePage: true,
        numberedPagination: true,
        columns: [
          AdminColumn(
            'Waktu UTC',
            (r) => '${r['terjadiPada']}'
                .replaceFirst('T', ' ')
                .replaceFirst('Z', ' UTC'),
          ),
          AdminColumn(
            'Aktivitas',
            (r) => auditActionLabels[r['aksi']] ?? r['aksi'],
          ),
          AdminColumn(
            'Hasil',
            (r) => auditResultLabels[r['hasil']] ?? r['hasil'],
          ),
          AdminColumn('Klien (klaim)', (r) => r['klien']),
          AdminColumn(
            'Detail',
            (_) => '',
            cell: (row) => TextButton(
              onPressed: () => showAuditDetail(row),
              child: const Text('Lihat detail'),
            ),
          ),
        ],
      ),
    Row(
      children: [
        Expanded(child: Text('Halaman $page/${snapshot['jumlahHalaman']}')),
        IconButton(
          tooltip: 'Sebelumnya',
          onPressed: locked || page <= 1
              ? null
              : () {
                  setState(() => page--);
                  unawaited(load());
                },
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Berikutnya',
          onPressed: locked || page >= (snapshot['jumlahHalaman'] as int)
              ? null
              : () {
                  setState(() => page++);
                  unawaited(load());
                },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  ];
  void showAuditDetail(Json row) {
    if (!controller.active || detailRoute != null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail aktivitas'),
        content: SingleChildScrollView(
          child: SelectableText(
            [
              'Aktivitas: ${row['aksi']}',
              'Hasil: ${row['hasil']}',
              'Kode: ${row['alasan']}',
              'Waktu UTC: ${row['terjadiPada']}',
              'Korelasi request: ${row['requestId']}',
              'Korelasi akun: ${row['akunRef'] ?? '—'}',
              'Korelasi aktor: ${row['aktorRef'] ?? '—'}',
              'Korelasi sesi: ${row['sesiRef'] ?? '—'}',
              'Jumlah sesi dicabut: ${row['jumlahSesi'] ?? '—'}',
              'Klien (klaim): ${row['klien']}',
              'Asal proses: ${row['sumber']} (belum diverifikasi)',
            ].join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
    detailRoute = route;
    detailNavigator = navigator;
    unawaited(
      navigator.push(route).whenComplete(() {
        if (identical(detailRoute, route)) detailRoute = null;
      }),
    );
  }
}
