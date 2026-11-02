import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'mobile_ui.dart';
import 'doctor_visual.dart';
import 'doctor_professional.dart';

/// Presentation model only. Waiting order and eligibility come from REST.
class DoctorDashboardData {
  DoctorDashboardData(this.appointments, this.snapshots) {
    final byKey = <String, Json>{};
    for (final a in appointments) {
      byKey[key(a)] = {...a, 'jenisAntrean': 'JANJI_TEMU'};
    }
    final ordered = <String>[];
    for (final s in snapshots) {
      for (final group in ['aktif', 'menunggu']) {
        for (final t in rows(s[group])) {
          final row = <String, dynamic>{
            ...t,
            'poliklinik': s['poliklinik'],
            'ruang': s['ruang'],
            'jadwalPraktikId': object(s['sesi'])['id'],
          };
          final id = key(row);
          byKey[id] = {...?byKey[id], ...row, 'dariSnapshot': true};
          if (!ordered.contains(id)) ordered.add(id);
          if (group == 'aktif') active.add(byKey[id]!);
          if (group == 'menunggu') waiting.add(byKey[id]!);
        }
      }
    }
    entries = [
      for (final id in ordered) byKey[id]!,
      for (final e in byKey.entries)
        if (!ordered.contains(e.key)) e.value,
    ];
  }
  final List<Json> appointments, snapshots;
  final List<Json> active = [], waiting = [];
  late final List<Json> entries;
  static String key(Json row) {
    String scope(Json value) =>
        '${value['id'] ?? value['kode'] ?? value['nama'] ?? ''}';
    return '${scope(object(row['poliklinik']))}|${scope(object(row['ruang']))}|${row['nomorAntrean']}';
  }

  int get queueTotal => snapshots.fold<int>(
    0,
    (n, s) =>
        n +
        ((s['totalMenunggu'] as num?)?.toInt() ?? 0) +
        rows(s['aktif']).length,
  );
  int get completed =>
      appointments.where((a) => a['status'] == 'SELESAI').length;
  Json? get nextEligible =>
      waiting.where((a) => a['layakDipanggil'] == true).firstOrNull;
}

String doctorStatus(Object? value) => switch ('$value') {
  'DIPESAN' => 'Dipesan',
  'CHECK_IN' => 'Check-In',
  'MENUNGGU' => 'Menunggu',
  'DIPANGGIL' => 'Dipanggil',
  'DILAYANI' => 'Dilayani',
  'SELESAI' => 'Selesai',
  'DILEWATI' => 'Dilewati',
  'DIBATALKAN' => 'Dibatalkan',
  _ => '${value ?? '—'}',
};
Color doctorStatusColor(Object? status) => switch ('$status') {
  'SELESAI' => QueueBStyle.success,
  'DIPANGGIL' || 'DILAYANI' => QueueBStyle.darkTeal,
  'DIBATALKAN' || 'DILEWATI' => QueueBStyle.danger,
  _ => QueueBStyle.warning,
};
Widget doctorBadge(String text, {Color color = QueueBStyle.darkTeal}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
String doctorTime(Json row, AppConfig config) {
  if (DateTime.tryParse('${row['mulaiPada']}') == null) return '—';
  return '${clockOnly(config.localInput(row['mulaiPada']))}–${clockOnly(config.localInput(row['selesaiPada']))}';
}

class DoctorPanel extends StatelessWidget {
  const DoctorPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DoctorStyle.panelPadding),
    decoration: DoctorStyle.panel,
    child: child,
  );
}

class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({
    super.key,
    required this.config,
    required this.date,
    required this.profile,
    required this.schedules,
    required this.appointments,
    required this.snapshots,
    required this.loading,
    required this.available,
    required this.status,
    required this.onRefresh,
    required this.onPickDate,
    this.error,
  });
  final AppConfig config;
  final String date;
  final Json profile;
  final List<Json> schedules, appointments, snapshots;
  final bool loading, available;
  final ValueListenable<String> status;
  final AsyncCallback onRefresh;
  final VoidCallback onPickDate;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final current = date == config.today;
    final data = DoctorDashboardData(
      available ? appointments : [],
      available && current ? snapshots : [],
    );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, box) {
          final desktop =
              box.maxWidth >= 1100 &&
              box.maxHeight >= 500 &&
              MediaQuery.textScalerOf(context).scale(14) <= 17.5;
          final compact = box.maxHeight < 720;
          final queue = DoctorQueuePanel(
            key: ValueKey((date, available)),
            entries: data.entries,
            config: config,
            date: date,
            available: available,
            loading: loading,
            expand: desktop,
            compact: compact,
          );
          final live = DoctorLivePanel(
            key: ValueKey((date, available)),
            data: data,
            config: config,
            available: available && current && snapshots.isNotEmpty,
            loading: loading,
            status: status,
            expand: desktop,
            compact: compact,
          );
          final schedule = _schedulePanel(
            context,
            data,
            current,
            expand: desktop,
            compact: compact,
          );
          final feedback = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (error != null) MobileNotice(error!, error: true),
            ],
          );
          if (desktop) {
            return CustomScrollView(
              key: const ValueKey('doctor-desktop-viewport'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _heading(context, current),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 70),
                          child: SingleChildScrollView(child: feedback),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 63, child: queue),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 37,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 7, child: live),
                                    const SizedBox(height: 12),
                                    Expanded(flex: 5, child: schedule),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            key: const ValueKey('doctor-page-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: DoctorStyle.pageInsets(context),
            children: [
              _heading(context, current),
              feedback,
              const SizedBox(height: 16),
              queue,
              const SizedBox(height: 16),
              live,
              const SizedBox(height: 16),
              schedule,
            ],
          );
        },
      ),
    );
  }

  Widget _heading(BuildContext context, bool current) => LayoutBuilder(
    builder: (context, box) {
      final clinics = available
          ? rows(profile['poliklinik']).map(label).join(' · ')
          : '';
      final rooms = available
          ? schedules
                .map((s) => object(s['ruang'])['kode'])
                .where((v) => v != null)
                .toSet()
                .join(' · ')
          : '';
      final title = Row(
        children: [
          ProfessionalDoctorAvatar(
            config: config,
            photo: available ? profile['fotoProfil'] : null,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available
                      ? 'Selamat datang, ${profile['nama'] ?? 'Dokter'}'
                      : 'Portal Dokter',
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: DoctorStyle.ink,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  available
                      ? [
                          if (profile['spesialisasi'] != null)
                            '${profile['spesialisasi']}',
                          if (clinics.isNotEmpty) clinics,
                          if (rooms.isNotEmpty) rooms,
                        ].join(' · ')
                      : 'Ringkasan praktik dan antrean Anda.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: QueueBStyle.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      final live = available && current && snapshots.isNotEmpty;
      final tools = Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        children: [
          DoctorStatusPill(
            label: !available
                ? 'Data belum tersedia'
                : live
                ? 'Praktik Aktif'
                : 'Tidak ada sesi live',
            color: live ? QueueBStyle.success : QueueBStyle.muted,
          ),
          DoctorDashboardClock(
            config: config,
            date: date,
            onPickDate: onPickDate,
            loading: loading,
          ),
          ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (context, value, _) => Tooltip(
              message: value,
              child: Icon(
                value == 'Realtime terhubung'
                    ? Icons.wifi_rounded
                    : Icons.sync_rounded,
                color: value == 'Realtime terhubung'
                    ? QueueBStyle.success
                    : QueueBStyle.muted,
                size: 20,
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Muat ulang portal dokter',
            onPressed: loading ? null : onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: DoctorStyle.rule),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
        ],
      );
      if (box.maxWidth >= 1080 &&
          MediaQuery.textScalerOf(context).scale(14) <= 17.5) {
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (box.maxWidth * .53).clamp(540.0, 720.0).toDouble(),
              ),
              child: tools,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 12), tools],
      );
    },
  );

  Widget _schedulePanel(
    BuildContext context,
    DoctorDashboardData data,
    bool current, {
    required bool expand,
    required bool compact,
  }) {
    final totalMinutes = available
        ? schedules.where((s) => s['aktif'] == true).fold<int>(0, (sum, s) {
            final start = DateTime.tryParse('${s['mulaiPada']}'),
                end = DateTime.tryParse('${s['selesaiPada']}');
            return sum +
                (start == null || end == null
                    ? 0
                    : math.max(0, end.difference(start).inMinutes));
          })
        : null;
    final duration = totalMinutes == null
        ? '—'
        : totalMinutes >= 60
        ? '${totalMinutes ~/ 60} j${totalMinutes % 60 == 0 ? '' : ' ${totalMinutes % 60} m'}'
        : '$totalMinutes m';
    Widget fact(IconData icon, String title, String value) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: DoctorStyle.primary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      color: QueueBStyle.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DoctorStyle.ink,
              ),
            ),
          ],
        ),
      ),
    );
    final list = !available
        ? const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Data jadwal belum tersedia.',
              style: TextStyle(color: QueueBStyle.muted, fontSize: 12),
            ),
          )
        : schedules.isEmpty
        ? const DoctorInfoBlock(
            icon: Icons.event_busy_outlined,
            child: Text(
              'Tidak ada jadwal pada tanggal pilihan.',
              style: TextStyle(color: QueueBStyle.muted, fontSize: 12),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in schedules) _schedule(s, compact: compact),
            ],
          );
    return DoctorPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              DoctorIconTile(
                icon: Icons.calendar_today_outlined,
                size: compact ? 30 : 36,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  current
                      ? 'Jadwal Praktik Hari Ini'
                      : 'Jadwal Praktik Terpilih',
                  style: TextStyle(
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    color: DoctorStyle.ink,
                  ),
                ),
              ),
              DoctorStatusPill(
                label: available ? '${schedules.length} sesi' : '—',
                color: DoctorStyle.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (expand)
            Expanded(child: SingleChildScrollView(child: list))
          else
            list,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: DoctorStyle.rule),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fact(Icons.access_time_rounded, 'Durasi sesi', duration),
              fact(
                Icons.task_alt_rounded,
                'Janji selesai',
                available ? '${data.completed}' : '—',
              ),
              fact(
                Icons.people_outline_rounded,
                'Menunggu dimuat',
                available
                    ? '${data.entries.where((r) => r['status'] == 'MENUNGGU').length}'
                    : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _schedule(Json s, {required bool compact}) {
    final start = DateTime.tryParse('${s['mulaiPada']}'),
        end = DateTime.tryParse('${s['selesaiPada']}');
    final sessionState = s['aktif'] != true
        ? 'Nonaktif'
        : start == null || end == null
        ? 'Waktu belum tersedia'
        : !end.isAfter(config.now)
        ? 'Selesai'
        : start.isAfter(config.now)
        ? 'Akan datang'
        : 'Berlangsung';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfff8faff),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: DoctorStyle.rule),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final identity = Row(
            children: [
              const DoctorIconTile(
                icon: Icons.event_available_outlined,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorTime(s, config),
                      style: TextStyle(
                        fontSize: compact ? 16 : 20,
                        fontWeight: FontWeight.w800,
                        color: DoctorStyle.ink,
                      ),
                    ),
                    Text(
                      '${object(s['ruang'])['kode'] ?? label(object(s['ruang']))} · ${label(object(s['poliklinik']))}',
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
          final badge = DoctorStatusPill(
            label: sessionState,
            color: sessionState == 'Berlangsung'
                ? QueueBStyle.success
                : QueueBStyle.muted,
          );
          return box.maxWidth >= 340 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18
              ? Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 8),
                    badge,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 6), badge],
                );
        },
      ),
    );
  }
}

void showDoctorQueueDetail(BuildContext context, Json row, AppConfig config) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detail antrean ${row['nomorAntrean'] ?? '—'}'),
        scrollable: true,
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label(object(row['poliklinik']))),
              Text(label(object(row['ruang']))),
              if (object(row['ruang'])['lokasi'] != null)
                Text('${object(row['ruang'])['lokasi']}'),
              const SizedBox(height: 12),
              Text('Waktu slot: ${doctorTime(row, config)}'),
              Text('Status: ${doctorStatus(row['status'])}'),
              if (row['layakDipanggil'] is bool)
                Text(
                  row['layakDipanggil'] == true
                      ? 'Layak dipanggil menurut antrean saat ini.'
                      : 'Belum layak dipanggil menurut antrean saat ini.',
                ),
              const SizedBox(height: 16),
              const Text(
                'Nama pasien, identitas dan catatan klinis tidak disediakan pada portal ini.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );

class DoctorQueuePanel extends StatefulWidget {
  const DoctorQueuePanel({
    super.key,
    required this.entries,
    required this.config,
    required this.date,
    required this.available,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  });
  final List<Json> entries;
  final AppConfig config;
  final String date;
  final bool available, loading, expand, compact;
  @override
  State<DoctorQueuePanel> createState() => _DoctorQueuePanelState();
}

class _DoctorQueuePanelState extends State<DoctorQueuePanel> {
  String search = '', group = 'all', clinic = '';
  int page = 0, pageSize = 5;
  String clinicKey(Json row) {
    final value = object(row['poliklinik']);
    return '${value['id'] ?? value['kode'] ?? value['nama'] ?? ''}';
  }

  bool inGroup(Json row, String value) => switch (value) {
    'waiting' => row['status'] == 'MENUNGGU',
    'active' => ['DIPANGGIL', 'DILAYANI'].contains(row['status']),
    'completed' => row['status'] == 'SELESAI',
    _ => true,
  };
  @override
  Widget build(BuildContext context) {
    final source = widget.available ? widget.entries : <Json>[];
    final clinics = <String, String>{
      for (final row in source)
        if (clinicKey(row).isNotEmpty)
          clinicKey(row): label(object(row['poliklinik'])),
    };
    if (clinic.isNotEmpty && !clinics.containsKey(clinic)) clinic = '';
    final scoped = source
        .where((row) => clinic.isEmpty || clinicKey(row) == clinic)
        .toList();
    final filtered = scoped
        .where(
          (row) =>
              inGroup(row, group) &&
              '${row['nomorAntrean'] ?? ''} ${label(object(row['poliklinik']))} ${label(object(row['ruang']))} ${object(row['ruang'])['kode'] ?? ''}'
                  .toLowerCase()
                  .contains(search),
        )
        .toList();
    Widget tab(String value, String title) => ChoiceChip(
      label: Text(
        '$title (${widget.available ? scoped.where((r) => inGroup(r, value)).length : '—'})',
      ),
      selected: group == value,
      showCheckmark: false,
      selectedColor: DoctorStyle.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: group == value ? Colors.white : DoctorStyle.ink,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(
        color: group == value ? DoctorStyle.primary : DoctorStyle.rule,
      ),
      materialTapTargetSize: widget.compact
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      visualDensity: widget.compact
          ? VisualDensity.compact
          : VisualDensity.standard,
      onSelected: (_) => setState(() {
        group = value;
        page = 0;
      }),
    );
    final tabs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tab('waiting', 'Menunggu'),
        const SizedBox(width: 6),
        tab('active', 'Dilayani'),
        const SizedBox(width: 6),
        tab('completed', 'Selesai'),
        const SizedBox(width: 6),
        tab('all', 'Semua'),
      ],
    );
    final table = LayoutBuilder(
      builder: (context, box) => _table(context, box, filtered),
    );
    return DoctorPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final title = Row(
                children: [
                  const DoctorIconTile(
                    icon: Icons.format_list_bulleted_rounded,
                    size: 34,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Daftar Antrean Poli',
                      style: TextStyle(
                        fontSize: widget.compact ? 16 : 19,
                        fontWeight: FontWeight.w800,
                        color: DoctorStyle.ink,
                      ),
                    ),
                  ),
                ],
              );
              return box.maxWidth >= 620 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 18
                  ? Row(
                      children: [
                        Expanded(flex: 4, child: title),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 7,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: tabs,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: tabs,
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final field = TextField(
                onChanged: (value) => setState(() {
                  search = value.trim().toLowerCase();
                  page = 0;
                }),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Cari nomor antrean, poli, atau ruang…',
                  hintStyle: TextStyle(fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, size: 21),
                  prefixIconConstraints: BoxConstraints(
                    minHeight: 40,
                    minWidth: 40,
                  ),
                ),
              );
              final filter = DropdownButtonFormField<String>(
                key: ValueKey(
                  'doctor-clinic:$clinic:${clinics.keys.join(',')}',
                ),
                initialValue: clinic,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Layanan',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  prefixIcon: Icon(Icons.filter_alt_outlined, size: 19),
                  prefixIconConstraints: BoxConstraints(
                    minHeight: 40,
                    minWidth: 36,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text(
                      'Semua layanan',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  for (final e in clinics.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                onChanged: !widget.available
                    ? null
                    : (value) => setState(() {
                        clinic = value ?? '';
                        page = 0;
                      }),
              );
              return box.maxWidth >= 560
                  ? Row(
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: 10),
                        SizedBox(width: 185, child: filter),
                      ],
                    )
                  : Column(
                      children: [field, const SizedBox(height: 10), filter],
                    );
            },
          ),
          const SizedBox(height: 10),
          if (widget.expand)
            Expanded(child: table)
          else
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(390),
              child: table,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Spacer(),
              const Tooltip(
                message: 'Identitas pasien dan catatan medis tidak disediakan. Pencarian berlaku pada data yang dimuat; snapshot maksimal 100 entri per sesi.',
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: QueueBStyle.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, BoxConstraints box, List<Json> filtered) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final wide = box.maxWidth >= 560 && scale <= 1.35;
    final footerHeight = (box.maxWidth < 440 ? 72 : 48) * scale;
    final headerHeight = wide ? 34 * scale : 0.0;
    final size =
        ((box.maxHeight - footerHeight - headerHeight - 8) /
                ((wide ? 68 : 148) * scale))
            .floor()
            .clamp(1, 5)
            .toInt();
    if (size != pageSize) {
      page = (page * pageSize) ~/ size;
      pageSize = size;
    }
    final pages = math.max(1, (filtered.length / size).ceil());
    page = page.clamp(0, pages - 1).toInt();
    final start = page * size;
    final shown = filtered.skip(start).take(size).toList();
    Widget cell(Widget child, int flex) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      ),
    );
    Widget number(Json row) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: DoctorStyle.paleBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${row['nomorAntrean'] ?? '—'}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: DoctorStyle.ink,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
    Widget kind(Json row) => Row(
      children: [
        const DoctorIconTile(icon: Icons.person_outline_rounded, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row['jenisAntrean'] == 'WALK_IN'
                    ? 'Walk-in'
                    : row['jenisAntrean'] == 'JANJI_TEMU'
                    ? 'Janji temu'
                    : 'Antrean',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DoctorStyle.ink,
                ),
              ),
              if (doctorTime(row, widget.config) != '—')
                Text(
                  doctorTime(row, widget.config),
                  style: const TextStyle(
                    fontSize: 11,
                    color: QueueBStyle.muted,
                  ),
                ),
              if (row['layakDipanggil'] == false)
                const Text(
                  'Belum layak dipanggil',
                  style: TextStyle(fontSize: 11, color: QueueBStyle.warning),
                ),
            ],
          ),
        ),
      ],
    );
    Widget service(Json row) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label(object(row['poliklinik'])),
          style: const TextStyle(fontSize: 13, color: DoctorStyle.ink),
        ),
        Text(
          '${object(row['ruang'])['kode'] ?? label(object(row['ruang']))}',
          style: const TextStyle(fontSize: 11, color: QueueBStyle.muted),
        ),
      ],
    );
    Widget state(Json row) => Align(
      alignment: Alignment.centerLeft,
      child: DoctorStatusPill(
        label: doctorStatus(row['status']),
        color: doctorStatusColor(row['status']),
        icon: row['status'] == 'MENUNGGU'
            ? Icons.schedule_rounded
            : row['status'] == 'SELESAI'
            ? Icons.check_circle_outline_rounded
            : Icons.circle,
      ),
    );
    Widget menu(Json row) => SizedBox(
      width: 36,
      child: PopupMenuButton<String>(
        tooltip: 'Detail antrean ${row['nomorAntrean']}',
        onSelected: (_) => showDoctorQueueDetail(context, row, widget.config),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'detail', child: Text('Detail antrean')),
        ],
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: 21,
          color: QueueBStyle.muted,
        ),
      ),
    );
    final list = shown.isEmpty
        ? Center(
            child: Text(
              !widget.available
                  ? widget.loading
                        ? 'Memuat data antrean…'
                        : 'Data antrean belum tersedia.'
                  : 'Belum ada antrean yang sesuai.',
              style: const TextStyle(fontSize: 13, color: QueueBStyle.muted),
            ),
          )
        : ListView.separated(
            primary: false,
            padding: EdgeInsets.zero,
            itemCount: shown.length,
            separatorBuilder: (_, i) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final row = shown[i],
                  active = [
                    'DIPANGGIL',
                    'DILAYANI',
                  ].contains(shown[i]['status']);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? DoctorStyle.paleBlue : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DoctorStyle.rule.withValues(alpha: .8),
                  ),
                ),
                child: wide
                    ? Row(
                        children: [
                          cell(number(row), 20),
                          cell(kind(row), 29),
                          cell(service(row), 28),
                          cell(state(row), 23),
                          menu(row),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                number(row),
                                const SizedBox(width: 10),
                                Expanded(child: state(row)),
                                menu(row),
                              ],
                            ),
                            const SizedBox(height: 8),
                            kind(row),
                            const SizedBox(height: 6),
                            service(row),
                          ],
                        ),
                      ),
              );
            },
          );
    final caption = Text(
      !widget.available
          ? 'Data belum tersedia'
          : filtered.isEmpty
          ? 'Menampilkan 0 antrean'
          : 'Menampilkan ${start + 1}–${start + shown.length} dari ${filtered.length} antrean',
      style: const TextStyle(fontSize: 11, color: QueueBStyle.muted),
    );
    final pagination = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Antrean sebelumnya',
          onPressed: page == 0 ? null : () => setState(() => page--),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        for (
          var index = math.max(0, page - 1);
          index <= math.min(pages - 1, page + 1);
          index++
        )
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              width: 36,
              child: index == page
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: DoctorStyle.primary,
                      ),
                      onPressed: () {},
                      child: Text('${index + 1}'),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => setState(() => page = index),
                      child: Text('${index + 1}'),
                    ),
            ),
          ),
        IconButton(
          tooltip: 'Antrean berikutnya',
          onPressed: page + 1 >= pages ? null : () => setState(() => page++),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0xfff5f7fc),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: QueueBStyle.muted,
              ),
              child: Row(
                children: [
                  cell(const Text('No. Antrean'), 20),
                  cell(const Text('Kunjungan'), 29),
                  cell(const Text('Layanan / Ruang'), 28),
                  cell(const Text('Status'), 23),
                  const SizedBox(width: 36),
                ],
              ),
            ),
          ),
        Expanded(child: list),
        const SizedBox(height: 6),
        if (box.maxWidth < 440 || scale > 1.35)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              caption,
              Align(alignment: Alignment.centerRight, child: pagination),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: caption),
              pagination,
            ],
          ),
      ],
    );
    final minimum = 145 * scale;
    return box.maxHeight < minimum
        ? SingleChildScrollView(
            child: SizedBox(height: minimum, child: content),
          )
        : content;
  }
}

class DoctorLivePanel extends StatefulWidget {
  const DoctorLivePanel({
    super.key,
    required this.data,
    required this.config,
    required this.available,
    required this.loading,
    required this.status,
    this.expand = false,
    this.compact = false,
  });
  final DoctorDashboardData data;
  final AppConfig config;
  final bool available, loading, expand, compact;
  final ValueListenable<String> status;
  @override
  State<DoctorLivePanel> createState() => _DoctorLivePanelState();
}

class _DoctorLivePanelState extends State<DoctorLivePanel> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    final active = widget.available ? widget.data.active : <Json>[];
    final ticket =
        active
            .where((a) => DoctorDashboardData.key(a) == selected)
            .firstOrNull ??
        active.firstOrNull;
    final next = widget.available ? widget.data.nextEligible : null;
    final compact = widget.compact;
    Widget fact(IconData icon, String title, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: DoctorStyle.liveMuted, size: compact ? 20 : 24),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: DoctorStyle.liveMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final card = Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ticket == null
                      ? const Color(0xffe7edff)
                      : ticket['status'] == 'DILAYANI'
                      ? const Color(0xffd9f8e7)
                      : const Color(0xffe5eeff),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: ticket?['status'] == 'DILAYANI'
                          ? QueueBStyle.success
                          : DoctorStyle.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        ticket == null
                            ? (widget.available
                                  ? 'Belum ada antrean aktif'
                                  : 'Antrean live belum tersedia')
                            : doctorStatus(ticket['status']),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ticket?['status'] == 'DILAYANI'
                              ? QueueBStyle.success
                              : DoctorStyle.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${ticket?['nomorAntrean'] ?? '—'}',
                style: TextStyle(
                  fontSize: compact ? 44 : 60,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                ticket == null
                    ? widget.loading
                          ? 'Memuat antrean…'
                          : widget.available
                          ? 'Belum ada nomor dipanggil.'
                          : 'Monitoring tersedia saat sesi praktik aktif.'
                    : '${object(ticket['ruang'])['kode'] ?? label(object(ticket['ruang']))} · ${ticket['jenisAntrean'] == 'WALK_IN'
                          ? 'Walk-in'
                          : ticket['jenisAntrean'] == 'JANJI_TEMU'
                          ? 'Janji temu'
                          : 'Antrean'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: DoctorStyle.liveMuted,
                ),
              ),
            ],
          );
          final metadata = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fact(
                Icons.medical_services_outlined,
                'Layanan',
                ticket == null ? '—' : label(object(ticket['poliklinik'])),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Colors.white24),
              ),
              fact(
                Icons.access_time_rounded,
                'Slot konsultasi',
                ticket == null ? '—' : doctorTime(ticket, widget.config),
              ),
            ],
          );
          return box.maxWidth >= 330 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18
              ? Row(
                  children: [
                    Expanded(flex: 6, child: identity),
                    Container(
                      width: 1,
                      height: 90,
                      color: Colors.white24,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(flex: 5, child: metadata),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: Colors.white24),
                    ),
                    metadata,
                  ],
                );
        },
      ),
    );
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final row in active)
                  ChoiceChip(
                    label: Text('${row['nomorAntrean']}'),
                    selected: identical(row, ticket),
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => selected = DoctorDashboardData.key(row)),
                  ),
              ],
            ),
          ),
        card,
      ],
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff214894), Color(0xff0d245c)],
        ),
        borderRadius: BorderRadius.circular(DoctorStyle.radius),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            height: compact ? 100 : 150,
            child: Image.asset(
              'assets/illustrations/staff_stethoscope_banner.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              cacheWidth: 1000,
              excludeFromSemantics: true,
              errorBuilder: (_, error, stack) => const SizedBox.shrink(),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xaa163777), Color(0xcc0d245c)],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.connected_tv_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Antrean Aktif',
                        style: TextStyle(
                          fontSize: compact ? 17 : 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: widget.status,
                      builder: (_, value, child) => Tooltip(
                        message: value,
                        child: Icon(
                          value == 'Realtime terhubung'
                              ? Icons.wifi_rounded
                              : Icons.sync_rounded,
                          color: DoctorStyle.liveMuted,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.expand)
                  Expanded(child: SingleChildScrollView(child: body))
                else
                  body,
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: ticket == null
                      ? null
                      : () => showDoctorQueueDetail(
                          context,
                          ticket,
                          widget.config,
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xffbac9ed),
                    side: const BorderSide(color: Colors.white54),
                    backgroundColor: Colors.white.withValues(alpha: .05),
                    minimumSize: const Size(44, 40),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 19),
                  label: const Text(
                    'Lihat detail antrean',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  next == null
                      ? 'Belum ada antrean berikutnya yang layak dipanggil.'
                      : 'Berikutnya yang layak: ${next['nomorAntrean']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: DoctorStyle.liveMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
