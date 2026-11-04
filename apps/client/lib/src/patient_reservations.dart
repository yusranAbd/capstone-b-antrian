import 'package:flutter/material.dart';

import 'config.dart';
import 'doctor_professional.dart';
import 'features/patient/models/patient_queue_models.dart';
import 'mobile_ui.dart';
import 'patient_design.dart';
import 'patient_ui.dart';

/// Read model only. Ticket identity/status stays authoritative; no booking state.
class PatientReservation {
  const PatientReservation(this.ticket, this.appointment, this.doctor);
  final Json ticket, doctor;
  final Json? appointment;
  Json get slot => object(appointment?['slotPraktik']);
  Json get session => object(slot['jadwalPraktik']);
  Json get clinic => object(ticket['layanan']).isNotEmpty
      ? object(ticket['layanan'])
      : object(object(session['dokterLayanan'])['layanan']);
  String get id => '${ticket['id']}';
  String get status => '${ticket['status'] ?? 'TIDAK_DIKETAHUI'}';
  String get day =>
      dateOnly(ticket['tanggalPelayanan'] ?? ticket['tanggalAntrean']);
  String get number =>
      '${ticket['nomorAntrean'] ?? appointment?['nomorAntrean'] ?? '—'}';
  bool get canCancel => appointment?['id'] != null && status == 'DIPESAN';
  bool get terminal => ['SELESAI', 'DIBATALKAN'].contains(status);
  String get title =>
      appointment == null ? 'Antrean harian / Walk-in' : label(doctor);
  String get searchText =>
      '$title ${doctor['spesialisasi'] ?? ''} ${label(clinic)} $number ${ticket['kodeTiket'] ?? ''} $day ${patientDate(day)}'
          .toLowerCase();
}

List<PatientReservation> patientReservations(
  List<Json> tickets,
  List<Json> appointments,
  List<Json> doctors,
  String today,
) {
  final byTicket = <String, Json>{
    for (final a in appointments)
      if (object(a['tiket'])['id'] != null) '${object(a['tiket'])['id']}': a,
  };
  final owned = <String, Json>{
    for (final a in appointments)
      if (object(a['tiket'])['id'] != null)
        '${object(a['tiket'])['id']}': {
          ...object(a['tiket']),
          if (a['tanggalPelayanan'] != null)
            'tanggalPelayanan': a['tanggalPelayanan'],
          if (a['nomorAntrean'] != null) 'nomorAntrean': a['nomorAntrean'],
        },
    // A fresh owned-ticket response wins over nested appointment status.
    for (final t in tickets)
      if (t['id'] != null) '${t['id']}': t,
  };
  final result = owned.entries.map((entry) {
    final a = byTicket[entry.key];
    final historical = object(
      object(
        object(object(a?['slotPraktik'])['jadwalPraktik'])['dokterLayanan'],
      )['dokter'],
    );
    final current = doctors
        .where((d) => d['id'] == historical['id'])
        .firstOrNull;
    return PatientReservation(entry.value, a, {
      ...?current,
      ...historical,
      if (historical['fotoProfil'] == null && current?['fotoProfil'] != null)
        'fotoProfil': current!['fotoProfil'],
    });
  }).toList();
  bool upcoming(PatientReservation r) =>
      !r.terminal && r.day.compareTo(today) >= 0;
  result.sort((a, b) {
    if (upcoming(a) != upcoming(b)) return upcoming(a) ? -1 : 1;
    final day = a.day.compareTo(b.day);
    if (day != 0) return upcoming(a) ? day : -day;
    final time = '${a.slot['mulaiPada'] ?? ''}'.compareTo(
      '${b.slot['mulaiPada'] ?? ''}',
    );
    if (time != 0) return upcoming(a) ? time : -time;
    return a.id.compareTo(b.id);
  });
  return result;
}

String reservationStatus(String value) => switch (value) {
  'DIPESAN' => 'Dipesan',
  'CHECK_IN' => 'Check-in',
  'MENUNGGU' => 'Menunggu',
  'DIPANGGIL' => 'Dipanggil',
  'DILAYANI' => 'Dilayani',
  'DILEWATI' => 'Dilewati',
  'SELESAI' => 'Selesai',
  'DIBATALKAN' => 'Dibatalkan',
  _ => value,
};

class ReservationStatus extends StatelessWidget {
  const ReservationStatus(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    final color = PatientDesign.statusInk(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PatientDesign.statusSurface(value),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PatientDesign.statusIcon(value), size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              reservationStatus(value),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.item,
    required this.config,
    required this.busy,
    required this.onTicket,
    required this.onCancel,
    this.queue,
  });
  final PatientReservation item;
  final AppConfig config;
  final bool busy;
  final VoidCallback onTicket, onCancel;
  final PatientQueueView? queue;

  String get _zone => switch (config.serviceTimeZone) {
    'Asia/Jakarta' => 'WIB',
    'Asia/Makassar' => 'WITA',
    'Asia/Jayapura' => 'WIT',
    _ => config.serviceTimeZone,
  };

  bool get _today =>
      validPatientQueueDate(item.day) && item.day == config.today;

  bool get _activeToday =>
      _today &&
      const [
        'CHECK_IN',
        'MENUNGGU',
        'DIPANGGIL',
        'DILAYANI',
        'DILEWATI',
      ].contains(item.status);

  PatientQueueSummary? get _summary {
    if (!_activeToday) return null;
    final summary = queue?.summary;
    final service = '${item.clinic['id'] ?? item.ticket['layananId'] ?? ''}';
    return service.isNotEmpty &&
            summary?.serviceId == service &&
            summary?.date == item.day
        ? summary
        : null;
  }

  String? get _room {
    final room = object(item.session['loket']);
    final name = '${room['nama'] ?? ''}'.trim();
    final location = '${room['lokasi'] ?? ''}'.trim();
    final parts = [
      if (name.isNotEmpty) name,
      if (location.isNotEmpty && location != name) location,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String get _primaryLabel => switch (item.status) {
    'SELESAI' => 'Lihat Detail Kunjungan',
    'DIBATALKAN' => 'Lihat Detail',
    _ => _activeToday ? 'Pantau Tiket & QR' : 'Buka Tiket',
  };

  @override
  Widget build(BuildContext context) {
    final doctorName = '${item.doctor['nama'] ?? ''}'.trim();
    final reference = '${item.ticket['kodeTiket'] ?? ''}'.trim();
    return Container(
      key: ValueKey('reservation-${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PatientDesign.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: PatientDesign.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_activeToday)
              Container(height: 4, color: PatientDesign.statusInk(item.status)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PatientDesign.soft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          clinicIcon(label(item.clinic)),
                          color: PatientDesign.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label(item.clinic),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                height: 1.3,
                                color: PatientDesign.ink,
                              ),
                            ),
                            if (doctorName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                doctorName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: PatientDesign.muted,
                                ),
                              ),
                            ] else if (item.appointment == null) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Antrean langsung / Walk-in',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: PatientDesign.muted,
                                ),
                              ),
                            ],
                            if (reference.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Kode tiket: $reference',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: PatientDesign.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_activeToday) ...[
                    if (item.appointment != null) ...[
                      _schedule(context),
                      const SizedBox(height: 8),
                    ],
                    _queuePanel(),
                  ] else
                    _schedule(context),
                  // An appointment state never replaces the ticket state.
                  if (item.appointment?['status'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Status janji temu: ${item.appointment!['status']}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: PatientDesign.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _actions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final identity = Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ReservationStatus(item.status),
          Text(
            item.number.trim().isEmpty || item.number == '—'
                ? 'Nomor belum tersedia'
                : 'Antrean ${item.number}',
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: PatientDesign.ink,
            ),
          ),
        ],
      );
      final date = Text(
        _today
            ? 'Hari ini'
            : validPatientQueueDate(item.day)
            ? patientCompactDate(item.day)
            : 'Tanggal belum tersedia',
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: PatientDesign.muted,
        ),
      );
      if (box.maxWidth < 276 ||
          MediaQuery.textScalerOf(context).scale(13) > 17) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [identity, const SizedBox(height: 6), date],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: identity),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * .36),
            child: date,
          ),
        ],
      );
    },
  );

  Widget _schedule(BuildContext context) {
    final hasSlotTime =
        DateTime.tryParse('${item.slot['mulaiPada']}') != null &&
        DateTime.tryParse('${item.slot['selesaiPada']}') != null;
    final time = hasSlotTime
        ? '${patientTime(item.slot, config)} $_zone'
        : item.appointment == null
        ? 'Tanpa slot konsultasi khusus'
        : 'Jam konsultasi belum tersedia';
    final room = _room;
    return Container(
      decoration: BoxDecoration(
        color: PatientDesign.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, box) {
          final day = _fact(
            Icons.calendar_today_outlined,
            item.status == 'SELESAI' ? 'Tanggal kunjungan' : 'Jadwal kunjungan',
            validPatientQueueDate(item.day)
                ? '${patientCompactDate(item.day)} ${DateTime.parse(item.day).year}'
                : 'Tanggal belum tersedia',
          );
          final consultation = _fact(
            Icons.schedule_outlined,
            room == null ? 'Waktu' : 'Waktu dan ruang',
            [time, ?room].join('\n'),
          );
          if (box.maxWidth < 256 ||
              MediaQuery.textScalerOf(context).scale(13) > 17) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [day, const SizedBox(height: 8), consultation],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: day),
              const SizedBox(width: 8),
              Expanded(child: consultation),
            ],
          );
        },
      ),
    );
  }

  Widget _queuePanel() {
    final summary = _summary;
    final live =
        summary != null &&
        queue?.live == true &&
        queue?.loading != true &&
        queue?.error != true;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PatientDesign.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 18,
                color: PatientDesign.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary == null
                      ? 'Status tiket Anda'
                      : live
                      ? 'Sedang dilayani'
                      : 'Data pelayanan terakhir',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: PatientDesign.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (summary == null) ...[
            Text(
              reservationStatus(item.status),
              style: const TextStyle(
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: PatientDesign.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              queue?.loading == true
                  ? 'Informasi pelayanan sedang dimuat. Buka tiket untuk melihat detail.'
                  : 'Buka tiket untuk memantau perkembangan antrean Anda.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: PatientDesign.muted,
              ),
            ),
          ] else ...[
            if (summary.serving.isEmpty)
              Text(
                live
                    ? 'Belum ada pelayanan aktif'
                    : 'Belum ada nomor pada data pelayanan terakhir',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: PatientDesign.ink,
                ),
              )
            else
              for (final serving in summary.serving)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${serving.roomCode} · ${serving.number}',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: PatientDesign.primary,
                    ),
                  ),
                ),
            const SizedBox(height: 4),
            Text(
              '${live ? 'Live' : 'Data terakhir'} · '
              '${config.instantLabel(summary.obtainedAt.toIso8601String()).split(' ').last} $_zone',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: PatientDesign.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final primary = FilledButton.icon(
        onPressed: busy ? null : onTicket,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor: _activeToday
              ? PatientDesign.primary
              : PatientDesign.soft,
          foregroundColor: _activeToday
              ? PatientDesign.paper
              : PatientDesign.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: Icon(
          item.terminal
              ? Icons.description_outlined
              : _activeToday
              ? Icons.qr_code_rounded
              : Icons.confirmation_number_outlined,
          size: 18,
        ),
        label: Text(_primaryLabel, textAlign: TextAlign.center),
      );
      if (!item.canCancel) return primary;
      final cancel = TextButton(
        onPressed: busy ? null : onCancel,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          foregroundColor: PatientDesign.danger,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, height: 1.3),
        ),
        child: const Text('Batalkan Reservasi', textAlign: TextAlign.center),
      );
      if (box.maxWidth < 284 ||
          MediaQuery.textScalerOf(context).scale(13) > 17) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 8), cancel],
        );
      }
      return Row(
        children: [
          Expanded(child: primary),
          const SizedBox(width: 8),
          Expanded(child: cancel),
        ],
      );
    },
  );

  Widget _fact(IconData icon, String title, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: PatientDesign.primary),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: PatientDesign.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: PatientDesign.ink,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class ReservationList extends StatefulWidget {
  const ReservationList({
    super.key,
    required this.items,
    required this.config,
    required this.loading,
    required this.busy,
    required this.onCreate,
    required this.onRefresh,
    required this.onTicket,
    required this.onCancel,
    this.error,
    this.message,
    this.queueState,
    this.dataAvailable = true,
  });
  final List<PatientReservation> items;
  final AppConfig config;
  final bool loading, busy;
  final String? error, message;
  final PatientQueueState? queueState;
  final bool dataAvailable;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;
  final ValueChanged<PatientReservation> onTicket, onCancel;
  @override
  State<ReservationList> createState() => _ReservationListState();
}

class _ReservationListState extends State<ReservationList> {
  final search = TextEditingController();
  final scroll = ScrollController();
  String filter = 'Semua';
  static const groups = [
    'Semua',
    'Dipesan',
    'Berlangsung',
    'Selesai',
    'Dibatalkan',
    'Riwayat',
  ];
  static const operational = {
    'CHECK_IN',
    'MENUNGGU',
    'DIPANGGIL',
    'DILAYANI',
    'DILEWATI',
  };

  bool matches(PatientReservation item, String choice) => switch (choice) {
    'Semua' => true,
    'Berlangsung' =>
      item.day == widget.config.today && operational.contains(item.status),
    'Riwayat' =>
      item.terminal ||
          (DateTime.tryParse(item.day) != null &&
              item.day.compareTo(widget.config.today) < 0),
    _ => reservationStatus(item.status) == choice,
  };

  int count(String choice) =>
      widget.items.where((r) => matches(r, choice)).length;
  String countLabel(String choice) =>
      widget.dataAvailable ? '${count(choice)}' : '—';

  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReservationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.error != null && widget.error != oldWidget.error) ||
        (widget.message != null && widget.message != oldWidget.message)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            scroll.hasClients &&
            scroll.positions.every(
              (position) => position.hasPixels && position.hasContentDimensions,
            )) {
          scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> chooseFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheet) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(sheet).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter Reservasi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup filter',
                  onPressed: () => Navigator.pop(sheet),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            for (final choice in [
              ...groups,
              'Check-in',
              'Menunggu',
              'Dipanggil',
              'Dilayani',
              'Dilewati',
            ])
              ListTile(
                dense: true,
                minVerticalPadding: 4,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                selected: filter == choice,
                selectedTileColor: PatientDesign.soft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(choice, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${countLabel(choice)} reservasi',
                  style: const TextStyle(fontSize: 11, height: 1.3),
                ),
                trailing: filter == choice
                    ? const Icon(
                        Icons.check_circle,
                        color: PatientDesign.primary,
                      )
                    : const Icon(
                        Icons.chevron_right,
                        color: PatientDesign.muted,
                      ),
                onTap: () => Navigator.pop(sheet, choice),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => filter = selected);
  }

  Widget heading() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, bounds) {
          const title = Text(
            'Reservasi Pasien',
            style: TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: PatientDesign.ink,
            ),
          );
          final history = OutlinedButton.icon(
            onPressed: widget.busy || widget.loading
                ? null
                : () => setState(() => filter = 'Riwayat'),
            style: OutlinedButton.styleFrom(
              backgroundColor: PatientDesign.soft,
              foregroundColor: PatientDesign.primary,
              side: BorderSide.none,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: Text(
              '${countLabel('Riwayat')} Riwayat',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          );
          if (bounds.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 6), history],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              history,
            ],
          );
        },
      ),
      const SizedBox(height: 4),
      const Text(
        'Kelola jadwal kunjungan dan antrean Anda.',
        style: TextStyle(fontSize: 13, height: 1.4, color: PatientDesign.muted),
      ),
      if (widget.error != null) ...[
        const SizedBox(height: 8),
        MobileNotice(widget.error!, error: true),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.busy || widget.loading ? null : widget.onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
          ),
        ),
      ],
      if (widget.message != null) MobileNotice(widget.message!, success: true),
      if (widget.loading) ...[
        const SizedBox(height: 8),
        const LinearProgressIndicator(semanticsLabel: 'Memuat reservasi'),
      ],
      const SizedBox(height: 10),
      TextField(
        controller: search,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: PatientDesign.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Cari nomor tiket, layanan, atau dokter…',
          hintStyle: const TextStyle(fontSize: 13, color: PatientDesign.muted),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: PatientDesign.muted,
          ),
          suffixIcon: IconButton(
            tooltip: 'Filter status reservasi',
            onPressed: widget.busy || widget.loading ? null : chooseFilter,
            icon: const Icon(Icons.tune_rounded, color: PatientDesign.muted),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: PatientDesign.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: PatientDesign.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: PatientDesign.primary,
              width: 2,
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final choice in [
              ...groups,
              if (!groups.contains(filter)) filter,
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: filter == choice,
                  showCheckmark: false,
                  selectedColor: PatientDesign.primary,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: filter == choice
                        ? PatientDesign.primary
                        : PatientDesign.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  avatar: choice == 'Dipesan'
                      ? Icon(
                          Icons.circle,
                          size: 10,
                          color: filter == choice
                              ? Colors.white
                              : PatientDesign.warning,
                        )
                      : null,
                  label: Text(
                    choice == 'Semua'
                        ? 'Semua (${countLabel('Semua')})'
                        : choice,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: filter == choice
                        ? Colors.white
                        : PatientDesign.muted,
                  ),
                  onSelected: (_) => setState(() => filter = choice),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final visible = widget.items
        .where(
          (r) =>
              matches(r, filter) &&
              r.searchText.contains(search.text.trim().toLowerCase()),
        )
        .toList();
    final rows = visible.isEmpty ? 1 : visible.length;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        key: const PageStorageKey('reservation-list'),
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: rows + 2,
        itemBuilder: (context, index) {
          if (index == 0) return heading();
          if (index == rows + 1) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                key: const ValueKey('create-reservation'),
                onPressed: widget.busy || widget.loading
                    ? null
                    : widget.onCreate,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: const Text(
                  'Buat Reservasi Baru',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
          if (visible.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_note_outlined,
                    color: PatientDesign.muted,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.loading
                        ? 'Memuat reservasi…'
                        : widget.error != null || !widget.dataAvailable
                        ? 'Reservasi belum dapat dimuat. Muat ulang untuk mencoba lagi.'
                        : search.text.trim().isNotEmpty || filter != 'Semua'
                        ? 'Tidak ada reservasi yang sesuai pencarian atau filter.'
                        : 'Belum ada reservasi. Buat reservasi untuk memilih jadwal kunjungan.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: PatientDesign.muted,
                    ),
                  ),
                  if (search.text.trim().isNotEmpty || filter != 'Semua')
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: () => setState(() {
                        search.clear();
                        filter = 'Semua';
                      }),
                      child: const Text('Hapus pencarian & filter'),
                    ),
                ],
              ),
            );
          }
          final item = visible[index - 1];
          final serviceId =
              '${item.ticket['layananId'] ?? item.clinic['id'] ?? ''}';
          return ReservationCard(
            item: item,
            config: widget.config,
            busy: widget.busy,
            queue: item.day == widget.config.today
                ? widget.queueState?.forService(
                    serviceId,
                    widget.config.today,
                    now: widget.config.now,
                  )
                : null,
            onTicket: () => widget.onTicket(item),
            onCancel: () => widget.onCancel(item),
          );
        },
      ),
    );
  }
}

Future<String?> chooseReservationMethod(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Buat Reservasi',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: PatientDesign.navy,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup pilihan reservasi',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Pilih cara membuat reservasi.',
              style: TextStyle(color: PatientDesign.muted),
            ),
            const SizedBox(height: 14),
            for (final choice in [
              (
                id: 'doctors',
                icon: Icons.person_outline,
                title: 'Cari Dokter',
                detail: 'Pilih dokter dan jadwal praktik.',
              ),
              (
                id: 'nearest',
                icon: Icons.calendar_month_outlined,
                title: 'Jadwal Terdekat',
                detail: 'Temukan slot konsultasi yang tersedia.',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: PatientDesign.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: PatientDesign.mint,
                      child: Icon(choice.icon, color: PatientDesign.darkTeal),
                    ),
                    title: Text(
                      choice.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      choice.detail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PatientDesign.muted,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.pop(context, choice.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

/// Pure presentation for the existing booking workflow; callbacks own API reads.
class ReservationDoctorChoice extends StatelessWidget {
  const ReservationDoctorChoice({
    super.key,
    required this.doctor,
    required this.clinic,
    required this.config,
    required this.onSelect,
    required this.schedule,
    this.slot,
  });
  final Json doctor, clinic;
  final Json? schedule, slot;
  final AppConfig config;
  final VoidCallback? onSelect;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: PatientDesign.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ProfessionalDoctorAvatar(
              config: config,
              photo: doctor['fotoProfil'],
              radius: 25,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label(doctor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: PatientDesign.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (doctor['spesialisasi'] != null)
                        '${doctor['spesialisasi']}',
                      label(clinic),
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PatientDesign.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: PatientDesign.mint.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 20,
                color: PatientDesign.darkTeal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  schedule == null
                      ? 'Belum ada jadwal praktik mendatang.'
                      : '${slot == null ? 'Jadwal terdekat' : 'Slot tersedia'}\n${patientDate('${schedule!['tanggal']}')} · ${patientTime(slot ?? schedule!, config)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PatientDesign.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: onSelect, child: const Text('Pilih Jadwal')),
      ],
    ),
  );
}

class ReservationChoices extends StatefulWidget {
  const ReservationChoices({
    super.key,
    required this.choices,
    required this.config,
    required this.busy,
    required this.onSelect,
  });
  final List<Json> choices;
  final AppConfig config;
  final bool busy;
  final ValueChanged<Json> onSelect;
  @override
  State<ReservationChoices> createState() => _ReservationChoicesState();
}

class _ReservationChoicesState extends State<ReservationChoices> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final max = widget.choices.isEmpty ? 0 : (widget.choices.length - 1) ~/ 10;
    if (page > max) page = max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in widget.choices.skip(page * 10).take(10))
          ReservationDoctorChoice(
            doctor: object(c['doctor']),
            clinic: object(c['clinic']),
            config: widget.config,
            schedule: c['session'] == null ? null : object(c['session']),
            slot: c['slot'] == null ? null : object(c['slot']),
            onSelect: widget.busy || c['session'] == null
                ? null
                : () => widget.onSelect(c),
          ),
        if (max > 0)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Halaman ${page + 1}/${max + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PatientDesign.muted,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Pilihan sebelumnya',
                onPressed: page > 0 ? () => setState(() => page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Pilihan berikutnya',
                onPressed: page < max ? () => setState(() => page++) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}
