import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'config.dart';
import 'mobile_ui.dart';
import 'service_category.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({
    super.key,
    required this.catalog,
    required this.config,
    required this.loading,
    required this.onSelect,
    this.administratorName,
    this.onRefresh,
    this.onSetup,
    this.error,
    this.activity,
    this.activityLoading = false,
    this.activityError,
  });
  final Map<String, List<Json>> catalog;
  final AppConfig config;
  final bool loading, activityLoading;
  final ValueChanged<int> onSelect;
  final String? administratorName, error, activityError;
  final VoidCallback? onRefresh, onSetup;
  final Json? activity;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final desktop =
          box.hasBoundedHeight &&
          box.maxWidth >= 960 &&
          box.maxHeight >=
              520 * (MediaQuery.textScalerOf(context).scale(14) / 14) &&
          MediaQuery.textScalerOf(context).scale(14) <= 17.5;
      final compact = box.maxHeight < 720;
      final period = object(activity?['periode']);
      final todayActivity =
          period['mulai'] == config.today && period['selesai'] == config.today
          ? activity
          : null;
      final upcoming =
          (catalog['/jadwal-praktik'] ?? <Json>[]).where((s) {
            final start = DateTime.tryParse('${s['mulaiPada']}'),
                end = DateTime.tryParse('${s['selesaiPada']}');
            return s['aktif'] == true &&
                start != null &&
                end != null &&
                end.isAfter(start) &&
                end.isAfter(config.now);
          }).toList()..sort(
            (a, b) =>
                DateTime.parse('${a['mulaiPada']}')
                    .compareTo(DateTime.parse('${b['mulaiPada']}')),
          );
      final welcome = _DashboardWelcome(
        config: config,
        name: administratorName,
        onRefresh: loading ? null : onRefresh,
        onSetup: onSetup,
        busy: loading,
      );
      final feedback = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 3),
          if (error != null) MobileNotice(error!, error: true),
        ],
      );
      Widget activities(bool expand) => _ActivityToday(
        report: todayActivity,
        config: config,
        loading: activityLoading,
        error: activityError,
        expand: expand,
        onOpen: () => onSelect(8),
      );
      Widget schedule(bool expand) => _UpcomingSchedule(
        sessions: upcoming,
        loaded: catalog.containsKey('/jadwal-praktik'),
        catalog: catalog,
        config: config,
        expand: expand,
        onOpen: () => onSelect(4),
      );
      if (desktop) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              welcome,
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 66),
                child: SingleChildScrollView(child: feedback),
              ),
              const SizedBox(height: 12),
              _metrics(compact: compact),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 64, child: _services(context, expand: true)),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 36,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: activities(true)),
                          const SizedBox(height: 12),
                          Expanded(child: schedule(true)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return ListView(
        shrinkWrap: !box.hasBoundedHeight,
        physics: box.hasBoundedHeight
            ? null
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(box.maxWidth < 360 ? 12 : 16),
        children: [
          welcome,
          feedback,
          const SizedBox(height: 12),
          _metrics(compact: true),
          const SizedBox(height: 14),
          _services(context, expand: false),
          const SizedBox(height: 12),
          activities(false),
          const SizedBox(height: 12),
          schedule(false),
        ],
      );
    },
  );

  Widget _metrics({required bool compact}) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 800
          ? 4
          : box.maxWidth >= 480
          ? 2
          : 1;
      final entries = <(String, String, IconData, int)>[
        ('Poliklinik', '/layanan', Icons.local_hospital_outlined, 0),
        ('Dokter', '/dokter', Icons.medical_services_outlined, 1),
        ('Ruang / Loket', '/loket', Icons.meeting_room_outlined, 2),
        ('Jadwal Praktik', '/jadwal-praktik', Icons.calendar_month_outlined, 4),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in entries)
            SizedBox(
              key: ValueKey('admin-metric-${item.$2}'),
              width: (box.maxWidth - 12 * (columns - 1)) / columns,
              child: _MasterMetric(
                title: item.$1,
                count: catalog.containsKey(item.$2)
                    ? catalog[item.$2]!.length
                    : null,
                active: catalog[item.$2]
                    ?.where((r) => r['aktif'] == true)
                    .length,
                icon: item.$3,
                compact: compact,
                onTap: loading ? null : () => onSelect(item.$4),
              ),
            ),
        ],
      );
    },
  );

  Widget _services(BuildContext context, {required bool expand}) {
    final clinics = catalog['/layanan'] ?? <Json>[];
    Widget table(double? height) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final footerReserve = 88.0 * scale;
      final noFooterCapacity = height == null
          ? 8
          : ((height - 40) / (52 * scale)).floor().clamp(1, 8).toInt();
      final size = height == null || clinics.length <= noFooterCapacity
          ? noFooterCapacity
          : ((height - 40 - footerReserve) / (52 * scale))
                .floor()
                .clamp(1, 8)
                .toInt();
      final visibleRows = math.max(1, math.min(size, clinics.length));
      final footer = clinics.length > size ? footerReserve : 0.0;
      final rowHeight = height == null
          ? 58.0
          : ((height - 40 - footer) / visibleRows).clamp(48.0, 76.0).toDouble();
      if (!catalog.containsKey('/layanan')) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Data layanan belum tersedia.',
              style: TextStyle(color: QueueBStyle.muted),
            ),
          ),
        );
      }
      if (clinics.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Belum ada poliklinik. Tambahkan layanan untuk memulai.',
              style: TextStyle(color: QueueBStyle.muted),
            ),
          ),
        );
      }
      return Theme(
        data: Theme.of(context).copyWith(
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
          ),
          dataTableTheme: Theme.of(context).dataTableTheme.copyWith(
            columnSpacing: 16,
            horizontalMargin: 8,
            headingRowColor: const WidgetStatePropertyAll(Color(0xffedf1ff)),
            headingTextStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: QueueBStyle.navy,
            ),
            dataTextStyle: const TextStyle(
              fontSize: 13,
              color: QueueBStyle.navy,
            ),
          ),
        ),
        child: SingleChildScrollView(
          child: AdminTable(
            compact: true,
            decorated: false,
            numberedPagination: true,
            hideFooterWhenSinglePage: true,
            minimumWidth: 0,
            pageSize: size,
            rowHeight: rowHeight,
            paginationLabel: 'layanan',
            rows: clinics,
            columns: [
              AdminColumn(
                'Poliklinik',
                (r) => label(r),
                cell: (r) => _ClinicName(clinic: r),
              ),
              AdminColumn(
                'Dokter terkait',
                (r) => catalog.containsKey('/dokter')
                    ? catalog['/dokter']!
                          .where(
                            (d) => rows(d['dokterLayanan']).any(
                              (l) =>
                                  l['layananId'] == r['id'] &&
                                  l['aktif'] == true,
                            ),
                          )
                          .length
                    : '—',
                numeric: true,
              ),
              AdminColumn(
                'Ruang',
                (r) => catalog.containsKey('/loket')
                    ? catalog['/loket']!
                          .where((room) => room['layananId'] == r['id'])
                          .length
                    : '—',
                numeric: true,
              ),
              AdminColumn(
                'Sesi praktik',
                (r) => catalog.containsKey('/jadwal-praktik')
                    ? catalog['/jadwal-praktik']!
                          .where(
                            (s) =>
                                object(s['dokterLayanan'])['layananId'] ==
                                r['id'],
                          )
                          .length
                    : '—',
                numeric: true,
              ),
              AdminColumn(
                'Status',
                (r) => r['aktif'] == true ? 'Aktif' : 'Nonaktif',
                cell: (r) => _DashboardBadge(
                  label: r['aktif'] == true ? 'Aktif' : 'Nonaktif',
                  color: r['aktif'] == true
                      ? QueueBStyle.success
                      : QueueBStyle.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _DashboardSection(
            icon: Icons.layers_outlined,
            title: 'Layanan per poliklinik',
            subtitle: 'Daftar layanan beserta data pendukungnya.',
            action: TextButton.icon(
              onPressed: loading ? null : () => onSelect(0),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              iconAlignment: IconAlignment.end,
              label: const Text('Kelola'),
            ),
          ),
          const SizedBox(height: 12),
          if (expand)
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => table(box.maxHeight),
              ),
            )
          else
            table(null),
        ],
      ),
    );
  }
}

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

class _DashboardWelcome extends StatelessWidget {
  const _DashboardWelcome({
    required this.config,
    required this.busy,
    this.name,
    this.onRefresh,
    this.onSetup,
  });
  final AppConfig config;
  final bool busy;
  final String? name;
  final VoidCallback? onRefresh, onSetup;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final title = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Color(0xff101e4a),
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Selamat datang, ${name?.trim().isNotEmpty == true ? name!.trim() : 'Administrator'}!',
            style: const TextStyle(fontSize: 13, color: QueueBStyle.muted),
          ),
        ],
      );
      final actions = Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xff334976),
                size: 23,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminDateLabel(config),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      config.serviceTimeZone,
                      style: const TextStyle(
                        fontSize: 11,
                        color: QueueBStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton.outlined(
            tooltip: 'Muat ulang dashboard',
            onPressed: onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AdminStyle.rule),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 22),
          ),
          if (onSetup != null)
            FilledButton.icon(
              onPressed: busy ? null : onSetup,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff3654d5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.account_tree_outlined, size: 20),
              label: const Text('Kelola Layanan Terpadu'),
            ),
        ],
      );
      return box.maxWidth >= 900 &&
              MediaQuery.textScalerOf(context).scale(14) <= 17.5
          ? Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 570),
                  child: actions,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 10), actions],
            );
    },
  );
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: AdminStyle.panel,
    child: child,
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
      final stacked =
          box.maxWidth < 360 && MediaQuery.textScalerOf(context).scale(14) > 20;
      final heading = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AdminStyle.sky,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xff3654d5), size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff101e4a),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: QueueBStyle.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null && !stacked) ...[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      );
      return stacked && action != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 8), action!],
            )
          : heading;
    },
  );
}

class _MasterMetric extends StatelessWidget {
  const _MasterMetric({
    required this.title,
    required this.count,
    required this.active,
    required this.icon,
    required this.compact,
    this.onTap,
  });
  final String title;
  final int? count, active;
  final IconData icon;
  final bool compact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AdminStyle.rule),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 9 : 12),
              decoration: BoxDecoration(
                color: AdminStyle.sky,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: compact ? 24 : 28,
                color: const Color(0xff3654d5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff253654),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        count == null ? '—' : '$count',
                        style: TextStyle(
                          fontSize: compact ? 30 : 34,
                          height: 1.05,
                          letterSpacing: -.6,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xff101e4a),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      _DashboardBadge(
                        label: count == null || active == null
                            ? '—'
                            : '$active aktif',
                        color: count == null
                            ? QueueBStyle.muted
                            : QueueBStyle.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClinicName extends StatelessWidget {
  const _ClinicName({required this.clinic});
  final Json clinic;
  @override
  Widget build(BuildContext context) {
    final icon = switch (serviceCategory(clinic)) {
      'APOTEK' => Icons.medication_outlined,
      'PENDAFTARAN' => Icons.assignment_outlined,
      _ => Icons.medical_services_outlined,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Tooltip(
        message: label(clinic),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AdminStyle.sky,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 21, color: const Color(0xff3654d5)),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label(clinic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (clinic['kode'] != null)
                    Text(
                      '${clinic['kode']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: QueueBStyle.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBadge extends StatelessWidget {
  const _DashboardBadge({
    required this.label,
    required this.color,
    this.dot = true,
  });
  final String label;
  final Color color;
  final bool dot;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActivityToday extends StatelessWidget {
  const _ActivityToday({
    required this.report,
    required this.config,
    required this.loading,
    required this.error,
    required this.expand,
    required this.onOpen,
  });
  final Json? report;
  final AppConfig config;
  final bool loading, expand;
  final String? error;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final summary = object(report?['ringkasan']);
    int? count(String key) =>
        summary[key] is num ? (summary[key] as num).toInt() : null;
    final waiting = count('menunggu'), called = count('dipanggil');
    final entries = <(String, int?, IconData, Color, String)>[
      (
        'Dalam antrean',
        waiting == null || called == null ? null : waiting + called,
        Icons.people_outline_rounded,
        const Color(0xff3654d5),
        'Tiket Menunggu dan Dipanggil pada tanggal pelayanan hari ini.',
      ),
      (
        'Sedang dilayani',
        count('dilayani'),
        Icons.play_arrow_outlined,
        const Color(0xff3654d5),
        'Tiket berstatus Dilayani pada tanggal pelayanan hari ini.',
      ),
      (
        'Pelayanan selesai',
        count('selesai'),
        Icons.check_circle_outline_rounded,
        QueueBStyle.success,
        'Tiket berstatus Selesai pada tanggal pelayanan hari ini.',
      ),
    ];
    Widget row((String, int?, IconData, Color, String) item) => Tooltip(
      message: item.$5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          children: [
            Icon(item.$3, size: 22, color: item.$4),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.$1,
                style: const TextStyle(fontSize: 13, color: Color(0xff253654)),
              ),
            ),
            Text(
              item.$2 == null ? '—' : '${item.$2}',
              style: const TextStyle(
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Color(0xff253654),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
    final content = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminStyle.rule),
      ),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AdminStyle.rule),
            if (expand)
              Expanded(child: row(entries[i]))
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: row(entries[i]),
              ),
          ],
        ],
      ),
    );
    return _DashboardPanel(
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message:
                error ??
                (report == null
                    ? 'Aktivitas hari ini belum tersedia.'
                    : 'Diperbarui ${config.instantLabel(report?['diperolehPada'])} · ${config.serviceTimeZone}'),
            child: _DashboardSection(
              icon: Icons.bar_chart_rounded,
              title: 'Aktivitas Hari Ini',
              subtitle: loading
                  ? 'Memuat aktivitas…'
                  : report == null
                  ? 'Data belum tersedia. Muat ulang untuk mencoba.'
                  : 'Ringkasan aktivitas layanan hari ini.',
              action: IconButton(
                tooltip: 'Laporan operasional',
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (expand) Expanded(child: content) else content,
        ],
      ),
    );
  }
}

class _UpcomingSchedule extends StatelessWidget {
  const _UpcomingSchedule({
    required this.sessions,
    required this.loaded,
    required this.catalog,
    required this.config,
    required this.expand,
    required this.onOpen,
  });
  final List<Json> sessions;
  final bool loaded, expand;
  final Map<String, List<Json>> catalog;
  final AppConfig config;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    Widget entry(Json s) {
      final room = object(s['loket']), link = object(s['dokterLayanan']);
      final clinic = object(link['layanan']).isNotEmpty
          ? object(link['layanan'])
          : (catalog['/layanan'] ?? <Json>[])
                    .where((r) => r['id'] == link['layananId'])
                    .firstOrNull ??
                <String, dynamic>{};
      final ongoing = !DateTime.parse('${s['mulaiPada']}').isAfter(config.now);
      final date = dateOnly(s['tanggal']);
      final time =
          '${config.instantLabel(s['mulaiPada']).split(' ').last}–${config.instantLabel(s['selesaiPada']).split(' ').last}';
      return Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xfff8faff),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminStyle.rule),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final details = Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminStyle.sky,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time.replaceFirst('–', '\n'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff253654),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room['kode'] ?? ''} · ${label(room)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label(clinic),
                        style: const TextStyle(
                          fontSize: 11,
                          color: QueueBStyle.muted,
                        ),
                      ),
                      if (date.isNotEmpty && date != config.today)
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 11,
                            color: QueueBStyle.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
            final state = _DashboardBadge(
              label: ongoing ? 'Berlangsung' : 'Akan datang',
              color: ongoing ? const Color(0xff3654d5) : QueueBStyle.muted,
              dot: false,
            );
            return box.maxWidth >= 350 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 17.5
                ? Row(
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 8),
                      state,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [details, const SizedBox(height: 6), state],
                  );
          },
        ),
      );
    }

    Widget list(int limit) => !loaded
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Data jadwal belum tersedia.',
              style: TextStyle(fontSize: 12, color: QueueBStyle.muted),
            ),
          )
        : sessions.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Belum ada sesi praktik aktif atau mendatang.',
              style: TextStyle(fontSize: 12, color: QueueBStyle.muted),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final s in sessions.take(limit)) entry(s)],
          );
    return _DashboardPanel(
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardSection(
            icon: Icons.calendar_today_outlined,
            title: 'Jadwal Terdekat',
            subtitle: loaded
                ? '${sessions.length} sesi aktif atau berikutnya.'
                : 'Jadwal belum tersedia.',
            action: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              iconAlignment: IconAlignment.end,
              label: const Text('Lihat semua', style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(height: 10),
          if (expand)
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final estimate = box.maxWidth >= 370 ? 76.0 : 104.0;
                  final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
                  final limit = (box.maxHeight / (estimate * scale))
                      .floor()
                      .clamp(1, 3)
                      .toInt();
                  return SingleChildScrollView(child: list(limit));
                },
              ),
            )
          else
            list(3),
        ],
      ),
    );
  }
}
