import 'dart:async';

import 'package:flutter/material.dart';

import 'config.dart';
import 'mobile_ui.dart';
import 'portal_header.dart';
import 'doctor_professional.dart';
import 'staff_ui.dart';
import 'queueb_value_motion.dart';

class StaffToolbar extends StatelessWidget implements PreferredSizeWidget {
  const StaffToolbar({
    super.key,
    required this.selection,
    required this.avatar,
    required this.name,
    required this.onProfile,
  });

  // The room picker remains in the dashboard content.
  final Widget selection, avatar;
  final String name;
  final VoidCallback onProfile;

  @override
  Size get preferredSize =>
      const Size.fromHeight(QueueBPortalHeader.toolbarHeight);

  @override
  Widget build(BuildContext context) => QueueBPortalHeader(
    portalTitle: 'Portal Petugas',
    portalIcon: Icons.people_outline_rounded,
    roleLabel: 'Petugas Pelayanan',
    avatar: avatar,
    name: name,
    onProfile: onProfile,
  );
}

class StaffDashboardClock extends StatefulWidget {
  const StaffDashboardClock({super.key, required this.config});
  final AppConfig config;
  @override
  State<StaffDashboardClock> createState() => _StaffDashboardClockState();
}

class _StaffDashboardClockState extends State<StaffDashboardClock> {
  late final Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.config.now;
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xfff7f9ff),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QueueBStyle.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: StaffStyle.ink,
            size: 22,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${days[now.weekday - 1]}, ${two(now.day)} ${months[now.month - 1]} ${now.year}',
                  style: const TextStyle(
                    color: StaffStyle.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Pukul ${two(now.hour)}.${two(now.minute)} · ${widget.config.serviceTimeZone}',
                  style: const TextStyle(
                    color: QueueBStyle.muted,
                    fontSize: 12,
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

class StaffScheduledDoctorSummary extends StatelessWidget {
  const StaffScheduledDoctorSummary({
    super.key,
    required this.config,
    required this.schedules,
    required this.onOpen,
    this.loading = false,
    this.failed = false,
  });
  final AppConfig config;
  final List<Json> schedules;
  final VoidCallback onOpen;
  final bool loading, failed;

  @override
  Widget build(BuildContext context) {
    final first = schedules.firstOrNull;
    final doctor = object(object(first?['dokterLayanan'])['dokter']);
    final names = schedules
        .map((s) => label(object(object(s['dokterLayanan'])['dokter'])))
        .toSet()
        .toList();
    final time = first == null
        ? ''
        : '${config.instantLabel(first['mulaiPada']).split(' ').last}–${config.instantLabel(first['selesaiPada']).split(' ').last}';
    return Tooltip(
      message: schedules.isEmpty
          ? 'Jadwal dokter untuk ruangan dan tanggal pelayanan ini'
          : names.join('\n'),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: QueueBStyle.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: schedules.isEmpty ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (first == null)
                  const Icon(
                    Icons.medical_services_outlined,
                    size: 25,
                    color: StaffStyle.blue,
                  )
                else
                  ProfessionalDoctorAvatar(
                    config: config,
                    photo: doctor['fotoProfil'],
                    radius: 16,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dokter terjadwal${time.isEmpty ? '' : ' · $time'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: QueueBStyle.muted,
                        ),
                      ),
                      Text(
                        loading && first == null
                            ? 'Memuat jadwal…'
                            : failed && first == null
                            ? 'Jadwal belum tersedia'
                            : first == null
                            ? 'Tidak ada jadwal'
                            : '${label(doctor)}${names.length > 1 ? ' +${names.length - 1}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: StaffStyle.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                if (schedules.isNotEmpty)
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: QueueBStyle.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StaffScheduledDoctors extends StatelessWidget {
  const StaffScheduledDoctors({
    super.key,
    required this.config,
    required this.schedules,
    required this.clinic,
    this.loading = false,
    this.failed = false,
  });
  final AppConfig config;
  final List<Json> schedules;
  final String clinic;
  final bool loading, failed;
  @override
  Widget build(BuildContext context) => Material(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StaffStyle.radius),
      side: const BorderSide(color: QueueBStyle.border),
    ),
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: schedules.isEmpty
          ? SizedBox(
              height: 40,
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    color: QueueBStyle.darkTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loading
                          ? 'Memuat dokter terjadwal…'
                          : failed
                          ? 'Jadwal belum dapat dimuat. Muat ulang antrean.'
                          : 'Tidak ada jadwal dokter untuk ruang dan tanggal ini.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: QueueBStyle.muted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 1000 && schedules.length > 1
                    ? 2
                    : 1;
                final horizontal =
                    (box.maxWidth - (columns - 1) * 16) / columns >= 540;
                final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
                final rowHeight = (horizontal ? 74.0 : 116.0) * scale;
                final visibleRows =
                    ((schedules.length + columns - 1) ~/ columns).clamp(1, 2);
                return SizedBox(
                  height: visibleRows * rowHeight + (visibleRows - 1) * 8,
                  child: GridView.builder(
                    primary: false,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: rowHeight,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: schedules.length,
                    itemBuilder: (context, i) {
                      final s = schedules[i],
                          doctor = object(object(s['dokterLayanan'])['dokter']);
                      final identity = Row(
                        children: [
                          ProfessionalDoctorAvatar(
                            config: config,
                            photo: doctor['fotoProfil'],
                            radius: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dokter terjadwal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    color: QueueBStyle.muted,
                                  ),
                                ),
                                Text(
                                  label(doctor),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  [
                                    if (doctor['spesialisasi'] != null)
                                      '${doctor['spesialisasi']}',
                                    clinic,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    color: QueueBStyle.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final time = Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: QueueBStyle.darkTeal,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dateOnly(s['tanggal'])}\n${config.instantLabel(s['mulaiPada']).split(' ').last} – ${config.instantLabel(s['selesaiPada']).split(' ').last} · ${config.serviceTimeZone}',
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                color: QueueBStyle.muted,
                              ),
                            ),
                          ),
                        ],
                      );
                      return horizontal
                          ? Row(
                              children: [
                                Expanded(child: identity),
                                const SizedBox(width: 12),
                                SizedBox(width: 175, child: time),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                identity,
                                const SizedBox(height: 6),
                                time,
                              ],
                            );
                    },
                  ),
                );
              },
            ),
    ),
  );
}

class StaffPatientList extends StatefulWidget {
  const StaffPatientList({
    super.key,
    required this.rows,
    required this.config,
    required this.busy,
    required this.onAction,
    this.serviceName = '—',
    this.compact = false,
  });
  final List<Json> rows;
  final AppConfig config;
  final bool busy, compact;
  final String serviceName;
  final void Function(Json row, String action) onAction;
  @override
  State<StaffPatientList> createState() => _StaffPatientListState();
}

class _StaffPatientListState extends State<StaffPatientList> {
  int page = 0;
  static const maxPageSize = 5;
  int renderedPageSize = maxPageSize;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final table = box.maxWidth >= 480 && scale <= 1.35;
        final showService = box.maxWidth >= 620;
        final footerHeight = 52 * scale;
        final headerHeight = table ? 30 * scale : 0;
        final rowHeight = (table ? 60 : 150) * scale;
        final size = widget.compact && box.hasBoundedHeight
            ? ((box.maxHeight - footerHeight - headerHeight) / rowHeight)
                  .floor()
                  .clamp(1, maxPageSize)
                  .toInt()
            : maxPageSize;
        if (renderedPageSize != size) {
          page = (page * renderedPageSize) ~/ size;
          renderedPageSize = size;
        }
        final total = widget.rows.length;
        final last = total == 0 ? 0 : (total - 1) ~/ size;
        if (page > last) page = last;
        final start = page * size;
        final shown = widget.rows.skip(start).take(size).toList();
        Widget cell(Widget child, int flex) => Expanded(
          flex: flex,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 8),
            child: child,
          ),
        );
        Widget menu(Json t) => SizedBox(
          width: 36,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            tooltip: 'Aksi ${t['nomorAntrean']}',
            enabled: !widget.busy,
            onSelected: (a) => widget.onAction(t, a),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'detail', child: Text('Detail tiket')),
              if (t['status'] == 'MENUNGGU' &&
                  t['bisaBatalkanSesiBerakhir'] == true)
                const PopupMenuItem(
                  value: 'batalkan-sesi-berakhir',
                  child: Text('Batalkan setelah sesi berakhir'),
                ),
              if (t['status'] == 'DILEWATI' && t['bisaAntreUlang'] == true)
                const PopupMenuItem(
                  value: 'antre-ulang',
                  child: Text('Kembalikan ke Antrean'),
                ),
              if (t['status'] == 'CHECK_IN' && t['bisaMasukAntrean'] == true)
                const PopupMenuItem(
                  value: 'masuk',
                  child: Text('Masuk Antrean'),
                ),
            ],
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 22,
              color: QueueBStyle.muted,
            ),
          ),
        );
        Widget number(Json t) => Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 10,
            vertical: widget.compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: StaffStyle.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${t['nomorAntrean'] ?? '—'}',
            style: TextStyle(
              color: StaffStyle.ink,
              fontSize: widget.compact ? 15 : 17,
              height: 1.1,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
        Widget name(Json t) => Row(
          children: [
            Container(
              padding: EdgeInsets.all(widget.compact ? 5 : 7),
              decoration: BoxDecoration(
                color: StaffStyle.soft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 22,
                color: Color(0xff6074e8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t['namaPasien'] ?? 'Nama belum tersedia'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StaffStyle.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (table && !showService)
                    Text(
                      widget.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: QueueBStyle.muted,
                      ),
                    ),
                  if (t['layakDipanggil'] == false)
                    Text(
                      '${t['alasanTidakLayak'] ?? 'Belum layak dipanggil'}'
                          .replaceAll('_', ' '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: QueueBStyle.warning,
                      ),
                    )
                  else if (t['checkInPada'] != null)
                    Text(
                      'Check-in ${widget.config.instantLabel(t['checkInPada']).split(' ').last}',
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
        Widget service() => Row(
          children: [
            const Icon(
              Icons.medical_services_outlined,
              size: 17,
              color: QueueBStyle.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.serviceName,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        );
        Widget pageButton(int index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: SizedBox(
            width: 36,
            child: index == page
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: StaffStyle.blue,
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
        );
        final content = Column(
          children: [
            if (table)
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: widget.compact ? 7 : 12,
                  horizontal: 4,
                ),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xfff5f6fc),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: QueueBStyle.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Row(
                    children: [
                      cell(const Text('No. Antrean'), 19),
                      cell(const Text('Nama Pasien'), 36),
                      if (showService) cell(const Text('Jenis Layanan'), 25),
                      cell(const Text('Status'), 23),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: shown.isEmpty
                  ? const StaffEmpty('Belum ada antrean yang sesuai.')
                  : ListView.separated(
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemCount: shown.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final t = shown[i];
                        final id = t['tiketId'] ?? t['id'];
                        return QueueBValueMotion(
                          key: ValueKey(id),
                          scope: id,
                          value: t['status'],
                          animateChild: false,
                          highlight: true,
                          highlightColor: QueueBStyle.teal,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: widget.compact ? 6 : 10,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: QueueBStyle.border.withValues(
                                  alpha: .75,
                                ),
                              ),
                            ),
                            child: table
                                ? Row(
                                    children: [
                                      cell(number(t), 19),
                                      cell(name(t), 36),
                                      if (showService) cell(service(), 25),
                                      cell(StaffStatusPill(t['status']), 23),
                                      menu(t),
                                    ],
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            number(t),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: StaffStatusPill(
                                                  t['status'],
                                                ),
                                              ),
                                            ),
                                            menu(t),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        name(t),
                                        const SizedBox(height: 8),
                                        service(),
                                      ],
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, footer) {
                final caption = Text(
                  total == 0
                      ? 'Menampilkan 0 antrean'
                      : 'Menampilkan ${start + 1}–${start + shown.length} dari $total antrean',
                  style: const TextStyle(
                    fontSize: 12,
                    color: QueueBStyle.muted,
                  ),
                );
                final pagination = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Halaman antrean sebelumnya',
                      onPressed: page > 0 ? () => setState(() => page--) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    for (
                      var index = (page - 1).clamp(0, last).toInt();
                      index <= (page + 1).clamp(0, last).toInt();
                      index++
                    )
                      pageButton(index),
                    IconButton(
                      tooltip: 'Halaman antrean berikutnya',
                      onPressed: page < last
                          ? () => setState(() => page++)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                );
                return footer.maxWidth < 500 ||
                        MediaQuery.textScalerOf(context).scale(12) > 16
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          caption,
                          Align(
                            alignment: Alignment.centerRight,
                            child: pagination,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: caption),
                          pagination,
                        ],
                      );
              },
            ),
          ],
        );
        final minimum = MediaQuery.textScalerOf(context)
            .scale(table ? 145 : 230);
        return box.hasBoundedHeight && box.maxHeight < minimum
            ? SingleChildScrollView(
                child: SizedBox(height: minimum, child: content),
              )
            : content;
      },
    );
  }
}
