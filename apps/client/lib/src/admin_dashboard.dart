import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'config.dart';
import 'mobile_ui.dart';
import 'service_category.dart';

abstract final class _DashboardColors {
  static const blue = Color(0xff1f4dbf);
  static const teal = Color(0xff006259);
  static const ink = Color(0xff0d1c2f);
  static const muted = Color(0xff52617a);
  static const soft = Color(0xffeff4ff);
  static const canvas = Color(0xfff8f9ff);
  static const border = Color(0xffe2e8f0);
}

/// Administrative, read-only projection of the existing catalogue and report.
/// Service totals are never presented as room telemetry or queue commands.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.catalog,
    required this.config,
    required this.loading,
    required this.onSelect,
    this.administratorName,
    this.onRefresh,
    this.onSetup,
    this.onExport,
    this.exporting = false,
    this.error,
    this.activity,
    this.activityLoading = false,
    this.activityError,
  });
  final Map<String, List<Json>> catalog;
  final AppConfig config;
  final bool loading, activityLoading, exporting;
  final ValueChanged<int> onSelect;
  final String? administratorName, error, activityError;
  final VoidCallback? onRefresh, onSetup, onExport;
  final Json? activity;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int servicePage = 0;
  bool get busy => widget.loading || widget.activityLoading;
  Json? get report {
    final period = object(widget.activity?['periode']);
    return period['mulai'] == widget.config.today &&
            period['selesai'] == widget.config.today &&
            period['layananId'] == null &&
            (period['zonaWaktu'] == null ||
                period['zonaWaktu'] == widget.config.serviceTimeZone)
        ? widget.activity
        : null;
  }

  List<Json> get reportRows => rows(report?['baris']);
  Json get summary => object(report?['ringkasan']);
  List<Json> get activeServices => (widget.catalog['/layanan'] ?? <Json>[])
      .where((r) => r['aktif'] == true)
      .toList();
  int? metric(Json source, String name) =>
      source[name] is num ? (source[name] as num).toInt() : null;
  Json serviceReport(Json service) => report == null
      ? <String, dynamic>{}
      : reportRows.where((r) => r['layananId'] == service['id']).firstOrNull ??
            <String, dynamic>{
              'totalTiket': 0,
              'menunggu': 0,
              'dilayani': 0,
              'selesai': 0,
              'dipanggil': 0,
              'checkIn': 0,
              'dibatalkan': 0,
            };

  int? capacity(Json service) {
    if (!widget.catalog.containsKey('/jadwal-layanan')) return null;
    const days = [
      'SENIN',
      'SELASA',
      'RABU',
      'KAMIS',
      'JUMAT',
      'SABTU',
      'MINGGU',
    ];
    final hours = (widget.catalog['/jadwal-layanan'] ?? <Json>[]).where(
      (r) =>
          (r['layananId'] ?? object(r['layanan'])['id']) == service['id'] &&
          r['aktif'] == true &&
          r['hari'] == days[widget.config.now.weekday - 1],
    );
    var total = 0;
    for (final h in hours) {
      if (h['kapasitasHarian'] is! num) return null;
      total += (h['kapasitasHarian'] as num).toInt();
    }
    return total;
  }

  int? used(Json service) {
    final row = serviceReport(service);
    final total = metric(row, 'totalTiket'),
        cancelled = metric(row, 'dibatalkan');
    return total == null || cancelled == null
        ? null
        : math.max(0, total - cancelled);
  }

  String get updated {
    final value = report?['diperolehPada'];
    return value == null
        ? 'Belum diperbarui'
        : 'Diperbarui ${widget.config.instantLabel(value)}';
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _DashboardColors.canvas,
    child: LayoutBuilder(
      builder: (context, bounds) => ListView(
        shrinkWrap: !bounds.hasBoundedHeight,
        physics: bounds.hasBoundedHeight
            ? null
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(bounds.maxWidth < 600 ? 12 : 20),
        children: [
          _welcome(context),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (widget.error != null) MobileNotice(widget.error!, error: true),
          if (widget.activityError != null)
            MobileNotice(widget.activityError!, error: true),
          const SizedBox(height: 16),
          _metrics(),
          const SizedBox(height: 20),
          _monitoring(),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth >= 1000 &&
                  MediaQuery.textScalerOf(context).scale(13) <= 17) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 66, child: _activityTable()),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 34,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _readiness(),
                          const SizedBox(height: 14),
                          _quota(),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _activityTable(),
                  const SizedBox(height: 14),
                  _readiness(),
                  const SizedBox(height: 14),
                  _quota(),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _welcome(BuildContext context) => _DashboardPanel(
    child: LayoutBuilder(
      builder: (context, box) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Dashboard Operasional',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: _DashboardColors.ink,
                    letterSpacing: -.4,
                  ),
                ),
                const _DashboardBadge(
                  label: 'MONITORING HARI INI',
                  color: _DashboardColors.blue,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ringkasan antrean, layanan, dan jadwal praktik hari ini.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _DashboardColors.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              updated,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: _DashboardColors.muted,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _DashboardColors.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: _DashboardColors.teal,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${adminDateLabel(widget.config)} · ${_zone(widget.config)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : widget.onRefresh,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Muat ulang'),
            ),
            FilledButton.icon(
              onPressed: busy || report == null || widget.exporting
                  ? null
                  : widget.onExport,
              style: FilledButton.styleFrom(
                backgroundColor: _DashboardColors.blue,
              ),
              icon: Icon(
                widget.exporting
                    ? Icons.hourglass_top_rounded
                    : Icons.file_download_outlined,
                size: 18,
              ),
              label: Text(widget.exporting ? 'Menyiapkan…' : 'Ekspor Laporan'),
            ),
          ],
        );
        if (box.maxWidth >= 980 &&
            MediaQuery.textScalerOf(context).scale(13) <= 16) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: actions,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [heading, const SizedBox(height: 12), actions],
        );
      },
    ),
  );

  Widget _metrics() => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 880
          ? 4
          : box.maxWidth >= 480
          ? 2
          : 1;
      final activeRows = activeServices;
      final capacities = activeRows.map(capacity).toList();
      final quotaKnown =
          widget.catalog.containsKey('/layanan') &&
          widget.catalog.containsKey('/jadwal-layanan') &&
          capacities.every((c) => c != null);
      final totalCapacity = quotaKnown
          ? capacities.fold<int>(0, (a, b) => a + (b ?? 0))
          : null;
      final totalUsed = report == null
          ? null
          : activeRows
                .where((s) => (capacity(s) ?? 0) > 0)
                .fold<int>(0, (a, s) => a + (used(s) ?? 0));
      final servingNames = reportRows
          .where((r) => (metric(r, 'dilayani') ?? 0) > 0)
          .map((r) => '${r['namaLayanan'] ?? ''}'.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      final waitSeconds = summary['rataTungguDetik'];
      final entries = <Widget>[
        _DashboardMetric(
          title: 'PASIEN TERDAFTAR',
          value: metric(summary, 'pasienUnik'),
          unit: 'pasien',
          icon: Icons.how_to_reg_outlined,
          color: _DashboardColors.blue,
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_number(metric(summary, 'totalTiket'))} tiket tercatat hari ini',
                style: _small,
              ),
              const SizedBox(height: 6),
              if (totalCapacity != null &&
                  totalCapacity > 0 &&
                  totalUsed != null) ...[
                Text(
                  '$totalUsed / $totalCapacity kuota layanan aktif terisi',
                  style: _small,
                ),
                const SizedBox(height: 6),
                _progress(totalUsed / totalCapacity, _DashboardColors.blue),
              ] else
                Text(
                  totalCapacity == 0
                      ? 'Belum ada kuota layanan hari ini'
                      : 'Kuota belum tersedia',
                  style: _small,
                ),
            ],
          ),
        ),
        _DashboardMetric(
          title: 'SEDANG DILAYANI',
          value: metric(summary, 'dilayani'),
          unit: 'tiket',
          icon: Icons.medical_services_outlined,
          color: _DashboardColors.teal,
          footer: servingNames.isNotEmpty
              ? Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final s in servingNames.take(3))
                      _DashboardBadge(label: s, color: _DashboardColors.teal),
                    if (servingNames.length > 3)
                      Text(
                        '+${servingNames.length - 3} layanan',
                        style: _small,
                      ),
                  ],
                )
              : Text(
                  report == null
                      ? 'Data pelayanan belum tersedia'
                      : metric(summary, 'dilayani') == 0
                      ? 'Belum ada pelayanan aktif'
                      : 'Rincian layanan belum tersedia',
                  style: _small,
                ),
        ),
        _DashboardMetric(
          title: 'SELESAI DILAYANI',
          value: metric(summary, 'selesai'),
          unit: 'tiket',
          icon: Icons.task_alt_outlined,
          color: _DashboardColors.blue,
          footer: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _DashboardColors.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: _DashboardColors.muted,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Rata-rata waktu tunggu', style: _small),
                ),
                const SizedBox(width: 6),
                Text(
                  waitSeconds is num &&
                          (metric(summary, 'sampelTunggu') ?? 0) > 0
                      ? '${(waitSeconds / 60).toStringAsFixed(1)} mnt'
                      : '—',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        _DashboardMetric(
          title: 'ANTREAN MENUNGGU',
          value: metric(summary, 'menunggu'),
          unit: 'tiket',
          icon: Icons.hourglass_top_outlined,
          color: const Color(0xffa43946),
          footer: Text(
            report == null
                ? 'Data antrean belum tersedia'
                : '${_number(metric(summary, 'dipanggil'))} dipanggil · ${_number(metric(summary, 'checkIn'))} check-in',
            style: _small,
          ),
        ),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < entries.length; i++)
            SizedBox(
              key: ValueKey('admin-operational-metric-$i'),
              width: (box.maxWidth - 12 * (columns - 1)) / columns,
              child: entries[i],
            ),
        ],
      );
    },
  );

  Widget _monitoring() => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final columns = box.maxWidth >= 880 * math.min(scale, 1.4)
          ? 4
          : box.maxWidth >= 500
          ? 2
          : 1;
      final services = activeServices;
      final pages = math.max(1, (services.length / columns).ceil());
      final page = servicePage.clamp(0, pages - 1).toInt();
      final visible = services.skip(page * columns).take(columns).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardSection(
            icon: Icons.hub_outlined,
            title: 'Monitoring Poliklinik & Layanan',
            subtitle:
                'Ringkasan layanan aktif pada tanggal pelayanan hari ini.',
            action: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  widget.catalog.containsKey('/layanan')
                      ? '${services.length} layanan aktif'
                      : 'Memuat layanan…',
                  style: _small,
                ),
                if (pages > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Layanan sebelumnya',
                        onPressed: page == 0
                            ? null
                            : () => setState(() => servicePage = page - 1),
                        icon: const Icon(Icons.chevron_left, size: 20),
                      ),
                      Text('${page + 1}/$pages', style: _small),
                      IconButton(
                        tooltip: 'Layanan berikutnya',
                        onPressed: page >= pages - 1
                            ? null
                            : () => setState(() => servicePage = page + 1),
                        icon: const Icon(Icons.chevron_right, size: 20),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            _DashboardPanel(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  widget.loading
                      ? 'Memuat layanan…'
                      : widget.catalog.containsKey('/layanan')
                      ? 'Belum ada layanan aktif.'
                      : 'Data layanan belum tersedia.',
                  style: _small,
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in visible)
                  SizedBox(
                    key: ValueKey('admin-service-${s['id']}'),
                    width: (box.maxWidth - 12 * (columns - 1)) / columns,
                    child: _serviceCard(s),
                  ),
              ],
            ),
        ],
      );
    },
  );

  Widget _serviceCard(Json service) {
    final schedulesKnown =
        widget.catalog.containsKey('/jadwal-praktik') && widget.error == null;
    final assignmentsKnown =
        widget.catalog.containsKey('/penugasan-petugas') &&
        widget.error == null;
    final rooms = (widget.catalog['/loket'] ?? <Json>[])
        .where(
          (r) =>
              r['aktif'] == true &&
              (r['layananId'] ?? object(r['layanan'])['id']) == service['id'],
        )
        .toList();
    final sessions =
        (widget.catalog['/jadwal-praktik'] ?? <Json>[])
            .where(
              (s) =>
                  schedulesKnown &&
                  s['aktif'] == true &&
                  object(s['dokterLayanan'])['aktif'] == true &&
                  object(object(s['dokterLayanan'])['dokter'])['aktif'] ==
                      true &&
                  object(object(s['dokterLayanan'])['layanan'])['aktif'] ==
                      true &&
                  dateOnly(s['tanggal']) == widget.config.today &&
                  (object(s['dokterLayanan'])['layananId'] ??
                          object(
                            object(s['dokterLayanan'])['layanan'],
                          )['id']) ==
                      service['id'] &&
                  object(s['loket'])['aktif'] == true,
            )
            .toList()
          ..sort((a, b) => '${a['mulaiPada']}'.compareTo('${b['mulaiPada']}'));
    final now = widget.config.now;
    final active = sessions
        .where(
          (s) =>
              (DateTime.tryParse('${s['mulaiPada']}')?.isAfter(now) == false) &&
              (DateTime.tryParse('${s['selesaiPada']}')?.isAfter(now) == true),
        )
        .firstOrNull;
    final next = sessions
        .where(
          (s) => DateTime.tryParse('${s['mulaiPada']}')?.isAfter(now) == true,
        )
        .firstOrNull;
    final schedule = active ?? next;
    final doctors = <String>{
      for (final s in sessions)
        if (object(object(s['dokterLayanan'])['dokter'])['nama']
            case final String name)
          name,
    };
    final assignments = (widget.catalog['/penugasan-petugas'] ?? <Json>[])
        .where(
          (a) =>
              assignmentsKnown &&
              a['aktif'] == true &&
              object(a['petugas'])['aktif'] == true &&
              object(a['petugas'])['peran'] == 'PETUGAS' &&
              rooms.any(
                (r) => r['id'] == (a['loketId'] ?? object(a['loket'])['id']),
              ) &&
              dateOnly(a['tanggalMulai']).compareTo(widget.config.today) <= 0 &&
              (a['tanggalSelesai'] == null ||
                  dateOnly(a['tanggalSelesai'])
                          .compareTo(widget.config.today) >=
                      0),
        );
    final staff = <String>{
      for (final a in assignments)
        if (object(a['petugas'])['nama'] case final String name) name,
    };
    final provider = doctors.isNotEmpty
        ? doctors.join(', ')
        : staff.isNotEmpty
        ? staff.join(', ')
        : null;
    final clinic = serviceCategory(service) == 'POLIKLINIK';
    final row = serviceReport(service);
    final code = rooms.length == 1
        ? '${rooms.first['kode'] ?? service['kode'] ?? ''}'
        : '${service['kode'] ?? ''}';
    final color = serviceCategory(service) == 'APOTEK'
        ? _DashboardColors.teal
        : _DashboardColors.blue;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _DashboardColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: _DashboardColors.soft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_serviceIcon(service), size: 22, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label(service),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (code.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(code, style: _small),
                      ],
                      const SizedBox(height: 4),
                      _DashboardBadge(
                        label: active != null
                            ? 'Sesi berlangsung'
                            : next != null
                            ? 'Terjadwal'
                            : 'Aktif',
                        color: active != null ? _DashboardColors.teal : color,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fact(
                  clinic
                      ? Icons.medical_services_outlined
                      : Icons.badge_outlined,
                  provider ??
                      (clinic
                          ? schedulesKnown
                                ? 'Belum ada dokter terjadwal hari ini'
                                : 'Jadwal dokter belum tersedia'
                          : assignmentsKnown
                          ? 'Belum ada penugasan aktif'
                          : 'Data penugasan belum tersedia'),
                  fontSize: 12,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _DashboardColors.soft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'ANTREAN MENUNGGU',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .4,
                          color: _DashboardColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _number(metric(row, 'menunggu')),
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        schedule == null
                            ? 'Ringkasan layanan hari ini'
                            : '${clockOnly(widget.config.localInput(schedule['mulaiPada']))}–${clockOnly(widget.config.localInput(schedule['selesaiPada']))} ${_zone(widget.config)}',
                        textAlign: TextAlign.center,
                        style: _small,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _cardStat(
                        'Tiket',
                        metric(row, 'totalTiket'),
                        _DashboardColors.ink,
                      ),
                    ),
                    Expanded(
                      child: _cardStat(
                        'Dilayani',
                        metric(row, 'dilayani'),
                        color,
                      ),
                    ),
                    Expanded(
                      child: _cardStat(
                        'Selesai',
                        metric(row, 'selesai'),
                        _DashboardColors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.loading
                            ? null
                            : () => widget.onSelect(clinic ? 4 : 0),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: Icon(
                          clinic
                              ? Icons.calendar_month_outlined
                              : Icons.tune_outlined,
                          size: 16,
                        ),
                        label: Text(
                          clinic ? 'Lihat Jadwal' : 'Kelola Layanan',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Kelola ruang/loket',
                      onPressed: widget.loading
                          ? null
                          : () => widget.onSelect(2),
                      style: IconButton.styleFrom(
                        backgroundColor: _DashboardColors.soft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.meeting_room_outlined,
                        size: 18,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityTable() => _DashboardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardSection(
          icon: Icons.manage_history_outlined,
          title: 'Aktivitas Layanan Hari Ini',
          subtitle: 'Ringkasan transaksi dan status antrean per layanan.',
          action: TextButton.icon(
            onPressed: () => widget.onSelect(8),
            icon: const Icon(Icons.arrow_forward, size: 16),
            iconAlignment: IconAlignment.end,
            label: const Text('Lihat Laporan'),
          ),
        ),
        const SizedBox(height: 14),
        if (report == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Text(
              widget.activityLoading
                  ? 'Memuat aktivitas…'
                  : 'Data aktivitas belum tersedia.',
              style: _small,
            ),
          )
        else if (reportRows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Text(
              'Belum ada transaksi pada tanggal pelayanan hari ini.',
              style: _small,
            ),
          )
        else
          AdminTable(
            compact: true,
            decorated: false,
            numberedPagination: true,
            hideFooterWhenSinglePage: true,
            minimumWidth: 580,
            pageSize: 5,
            rowHeight: 50,
            paginationLabel: 'layanan',
            rows: reportRows
                .map(
                  (r) => <String, dynamic>{
                    ...r,
                    'id': '${r['layananId']}:${r['tanggal']}',
                  },
                )
                .toList(),
            columns: [
              AdminColumn(
                'Layanan',
                (r) => '${r['namaLayanan'] ?? '—'}',
                cell: (r) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['namaLayanan'] ?? '—'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text('${r['kodeLayanan'] ?? ''}', style: _small),
                  ],
                ),
              ),
              AdminColumn(
                'Tiket',
                (r) => _number(metric(r, 'totalTiket')),
                numeric: true,
              ),
              AdminColumn(
                'Menunggu',
                (r) => _number(metric(r, 'menunggu')),
                numeric: true,
              ),
              AdminColumn(
                'Dilayani',
                (r) => _number(metric(r, 'dilayani')),
                numeric: true,
              ),
              AdminColumn(
                'Selesai',
                (r) => _number(metric(r, 'selesai')),
                numeric: true,
              ),
            ],
          ),
        const SizedBox(height: 10),
        Text(updated, style: _small),
      ],
    ),
  );

  Widget _readiness() {
    final ready = (widget.catalog['/layanan/kesiapan'] ?? <Json>[])
        .where(
          (r) =>
              r['tanggalPenilaian'] == widget.config.today &&
              activeServices.any((s) => s['id'] == r['layananId']),
        )
        .toList();
    final incomplete = ready.where((r) => r['lengkap'] == false).toList();
    final known =
        activeServices.isNotEmpty &&
        !widget.loading &&
        widget.error == null &&
        ready.length == activeServices.length &&
        widget.catalog.containsKey('/layanan/kesiapan') &&
        widget.catalog.containsKey('/layanan');
    final hasMissing = known && incomplete.isNotEmpty;
    final color = hasMissing ? const Color(0xff825400) : _DashboardColors.teal;
    return _DashboardPanel(
      color: hasMissing ? const Color(0xfffff6e6) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardSection(
            icon: hasMissing
                ? Icons.fact_check_outlined
                : Icons.verified_outlined,
            title: 'Kelengkapan Konfigurasi',
            subtitle: !known
                ? 'Data kesiapan belum tersedia.'
                : hasMissing
                ? '${incomplete.length} layanan perlu dilengkapi.'
                : 'Konfigurasi layanan aktif sudah lengkap.',
          ),
          for (final r in known ? incomplete.take(2) : <Json>[]) ...[
            const SizedBox(height: 10),
            Text(
              label(
                activeServices
                        .where((s) => s['id'] == r['layananId'])
                        .firstOrNull ??
                    {},
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              (r['kekurangan'] is List
                  ? (r['kekurangan'] as List).map((v) => '$v').join(' · ')
                  : 'Periksa konfigurasi layanan.'),
              style: _small,
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: widget.loading ? null : widget.onSetup,
            icon: const Icon(Icons.account_tree_outlined, size: 16),
            label: Text(
              hasMissing ? 'Lengkapi Layanan' : 'Kelola Layanan Terpadu',
            ),
          ),
        ],
      ),
    );
  }

  Widget _quota() {
    final services = activeServices
        .where((s) => (capacity(s) ?? 0) > 0)
        .toList();
    final allCapacityKnown =
        widget.catalog.containsKey('/jadwal-layanan') &&
        widget.catalog.containsKey('/layanan') &&
        activeServices.every((s) => capacity(s) != null);
    final total = allCapacityKnown
        ? services.fold<int>(0, (a, s) => a + (capacity(s) ?? 0))
        : null;
    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardSection(
            icon: Icons.donut_large_outlined,
            title: 'Utilisasi Kuota Harian',
            subtitle: total == null
                ? 'Kuota belum tersedia.'
                : 'Total kuota: $total tiket',
          ),
          const SizedBox(height: 14),
          if (services.isEmpty)
            Text(
              allCapacityKnown
                  ? 'Belum ada kapasitas layanan pada hari ini.'
                  : 'Data kapasitas belum tersedia.',
              style: _small,
            ),
          for (final s in services.take(4)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label(s),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_number(used(s))} / ${capacity(s)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _DashboardColors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _progress(
              used(s) == null ? null : used(s)! / capacity(s)!,
              _DashboardColors.blue,
            ),
            const SizedBox(height: 4),
            Text(
              used(s) == null
                  ? 'Pemakaian belum tersedia'
                  : '${(used(s)! / capacity(s)! * 100).toStringAsFixed(0)}% terisi · ${math.max(0, capacity(s)! - used(s)!)} kuota tersisa',
              style: _small,
            ),
            const SizedBox(height: 14),
          ],
          TextButton.icon(
            onPressed: () => widget.onSelect(3),
            icon: const Icon(Icons.arrow_forward, size: 16),
            iconAlignment: IconAlignment.end,
            label: const Text('Atur Jam & Kapasitas'),
          ),
        ],
      ),
    );
  }
}

const _small = TextStyle(
  fontSize: 11,
  height: 1.4,
  color: _DashboardColors.muted,
);
String _number(int? value) => value == null ? '—' : '$value';
String _zone(AppConfig config) => switch (config.serviceTimeZone) {
  'Asia/Jakarta' => 'WIB',
  'Asia/Makassar' => 'WITA',
  'Asia/Jayapura' => 'WIT',
  _ => config.serviceTimeZone,
};
IconData _serviceIcon(Json service) => switch (serviceCategory(service)) {
  'APOTEK' => Icons.medication_outlined,
  'PENDAFTARAN' => Icons.assignment_outlined,
  'LABORATORIUM' => Icons.science_outlined,
  'RADIOLOGI' => Icons.monitor_heart_outlined,
  _ => Icons.medical_services_outlined,
};
Widget _fact(IconData icon, String value, {double fontSize = 13}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Icon(icon, size: 18, color: _DashboardColors.blue),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        value,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.4,
          color: _DashboardColors.ink,
        ),
      ),
    ),
  ],
);
Widget _cardStat(String label, int? value, Color color) => Column(
  children: [
    Text(label, style: _small, textAlign: TextAlign.center),
    const SizedBox(height: 3),
    Text(
      _number(value),
      style: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  ],
);
Widget _progress(double? value, Color color) => ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: value == null
      ? const SizedBox(
          height: 5,
          child: ColoredBox(color: _DashboardColors.soft),
        )
      : LinearProgressIndicator(
          value: value.clamp(0.0, 1.0).toDouble(),
          minHeight: 5,
          color: color,
          backgroundColor: _DashboardColors.soft,
        ),
);

String adminDateLabel(AppConfig config) {
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const months = [
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
  final now = config.now;
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _DashboardColors.border),
    ),
    child: child,
  );
}

class _DashboardBadge extends StatelessWidget {
  const _DashboardBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final heading = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: _DashboardColors.blue),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: _small),
                ],
              ],
            ),
          ),
        ],
      );
      if (action == null) return heading;
      if (box.maxWidth < 600 ||
          MediaQuery.textScalerOf(context).scale(13) > 17) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: action!),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 12),
          action!,
        ],
      );
    },
  );
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.footer,
  });
  final String title, unit;
  final int? value;
  final IconData icon;
  final Color color;
  final Widget footer;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: _DashboardColors.border),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 168),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .3,
                      color: _DashboardColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _number(value),
                    style: const TextStyle(
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: _DashboardColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: '  $unit',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _DashboardColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            footer,
          ],
        ),
      ),
    ),
  );
}
