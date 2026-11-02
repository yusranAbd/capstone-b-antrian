import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'api.dart';
import 'config.dart';
import 'features/staff/application/staff_queue_bloc.dart';
import 'features/staff/application/staff_queue_event.dart';
import 'features/staff/application/staff_queue_state.dart';
import 'features/staff/data/staff_queue_repository.dart';
import 'features/staff/models/staff_queue_models.dart';
import 'staff_qr_scanner.dart';
import 'mobile_ui.dart';
import 'staff_ui.dart';
import 'staff_v4.dart';
import 'queueb_motion.dart';
import 'queueb_value_motion.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({
    super.key,
    required this.api,
    this.headerBuilder,
    this.repository,
  });
  final QueueApi api;
  final StaffQueueRepository? repository;
  final PreferredSizeWidget Function(Widget context)? headerBuilder;
  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> with WidgetsBindingObserver {
  late final repository = widget.repository ?? StaffQueueRepository(widget.api);
  late final bloc = StaffQueueBloc(repository);
  final search = TextEditingController();
  String queueTab = 'waiting';
  DialogRoute<void>? _scanRoute;
  DialogRoute<void>? _detailRoute;
  DialogRoute<String>? _resolutionRoute;
  NavigatorState? _scannerNavigator;
  StaffQueueState get state => bloc.state;
  List<Json> get validAssignments => state.assignments;
  Json? get selectedRoom => state.room;
  String? get roomId => state.roomId;
  Json? get snapshot => state.snapshot;
  List<Json> get active => state.active;
  List<Json> get patients => state.patients;
  List<Json> get schedules => state.schedules;
  bool get scheduleLoading => state.scheduleLoading;
  bool get scheduleFailed => state.scheduleFailed;
  bool get loading => state.loading;
  bool get busy => state.blocked;
  String? get error => state.error;
  String? get message => state.message;
  int get followupPage => state.page;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(bloc.refresh(assignments: true));
  }

  Future<void> loadAssignments() => bloc.refresh(assignments: true);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(bloc.refresh());
  }

  Future<void> action(String path) async {
    final parts = path.split('/');
    final operation = StaffOperation.values
        .where((o) => o.route == parts.last)
        .first;
    try {
      await bloc.execute(
        operation,
        ticketId: parts.length == 4 ? parts[2] : null,
      );
    } on ApiException {
      // Feedback comes from feature state; no transport or snapshot lives here.
    }
  }

  Future<Json> submitQr(String value) =>
      bloc.execute(StaffOperation.scan, qr: value.trim());
  Future<void> scan() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StaffQrScanner(onScan: submitQr),
    );
    _scanRoute = route;
    _scannerNavigator = navigator;
    try {
      await navigator.push(route);
    } finally {
      if (identical(_scanRoute, route)) _scanRoute = null;
    }
  }

  void _closeDialogs() {
    final routes = <Route<dynamic>?>[
          _scanRoute,
          _detailRoute,
          _resolutionRoute,
        ],
        navigator = _scannerNavigator;
    _scanRoute = null;
    _detailRoute = null;
    _resolutionRoute = null;
    scheduleMicrotask(() {
      for (final route in routes) {
        if (navigator != null && navigator.mounted && route?.isActive == true) {
          navigator.removeRoute(route!);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeDialogs();
    unawaited(bloc.close());
    if (widget.repository == null) repository.dispose();
    search.dispose();
    super.dispose();
  }

  Widget roomChoice() => DropdownButtonFormField<String>(
    key: ValueKey(
      'staff-room:$roomId:${validAssignments.map((a) => a['loketId']).join(',')}',
    ),
    initialValue: validAssignments.any((a) => '${a['loketId']}' == roomId)
        ? roomId
        : null,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Ruangan yang ditugaskan',
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
      prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 40),
      hintText: 'Pilih ruangan pelayanan',
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    items: [
      for (final assignment in validAssignments)
        DropdownMenuItem(
          value: '${assignment['loketId']}',
          child: Text(
            '${object(assignment['loket'])['kode'] ?? ''} · ${label(object(assignment['loket']))} – ${label(object(object(assignment['loket'])['layanan']))}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
    ],
    onChanged: state.busy || loading
        ? null
        : (value) {
            if (value == null) return;
            search.clear();
            queueTab = 'waiting';
            bloc.add(StaffRoomSelected(value));
          },
  );
  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: bloc,
    child: BlocConsumer<StaffQueueBloc, StaffQueueState>(
      // Connection-only changes rebuild the status selector below.
      buildWhen: (previous, next) =>
          previous.liveStatus == next.liveStatus ||
          previous.roomId != next.roomId ||
          previous.load != next.load ||
          previous.command != next.command,
      listenWhen: (previous, next) =>
          (previous.load != next.load && next.load == StaffLoad.ended) ||
          previous.roomId != next.roomId ||
          previous.date != next.date,
      listener: (context, value) {
        search.clear();
        queueTab = 'waiting';
        _closeDialogs();
      },
      builder: (context, _) => buildPortal(context),
    ),
  );
  void rowAction(Json row, String route) {
    if (route == 'detail') {
      final navigator = Navigator.of(context, rootNavigator: true);
      final detail = DialogRoute<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${row['nomorAntrean']}'),
          content: Text(
            '${row['namaPasien'] ?? 'Nama belum tersedia'}\nStatus: ${row['status']}\nCheck-in: ${widget.api.config.instantLabel(row['checkInPada'])}${row['layakDipanggil'] == false ? '\n${row['alasanTidakLayak'] ?? 'Belum layak dipanggil'}' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      _detailRoute = detail;
      _scannerNavigator = navigator;
      unawaited(
        navigator.push(detail).whenComplete(() {
          if (identical(_detailRoute, detail)) _detailRoute = null;
        }),
      );
    } else if (route == 'batalkan-sesi-berakhir' &&
        row['status'] == 'MENUNGGU' &&
        row['bisaBatalkanSesiBerakhir'] == true) {
      unawaited(cancelEndedSession(row));
    } else if (row['status'] == 'DILEWATI' &&
            row['bisaAntreUlang'] == true &&
            route == 'antre-ulang' ||
        row['status'] == 'CHECK_IN' &&
            row['bisaMasukAntrean'] == true &&
            route == 'masuk') {
      action('/queue/${row['tiketId']}/$route');
    }
  }

  Future<void> cancelEndedSession(Json row) async {
    if (busy || _resolutionRoute != null) return;
    final room = roomId, date = state.date;
    String? reason;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Batalkan ${row['nomorAntrean']}?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sesi praktik sudah berakhir. Pastikan tindak lanjut telah dikoordinasikan dengan pasien. Tiket akan dibatalkan dan alasannya dicatat dalam riwayat pelayanan.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Alasan pembatalan',
                  ),
                  items: [
                    for (final entry in staffEndedSessionReasons.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() => reason = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali'),
            ),
            FilledButton(
              onPressed: reason == null
                  ? null
                  : () => Navigator.pop(context, reason),
              child: const Text('Batalkan tiket'),
            ),
          ],
        ),
      ),
    );
    _resolutionRoute = route;
    _scannerNavigator = navigator;
    String? selected;
    try {
      selected = await navigator.push(route);
    } finally {
      if (identical(_resolutionRoute, route)) _resolutionRoute = null;
    }
    if (!mounted ||
        !repository.active ||
        selected == null ||
        roomId != room ||
        state.date != date ||
        busy) {
      return;
    }
    try {
      await bloc.execute(
        StaffOperation.cancelEnded,
        ticketId: '${row['tiketId']}',
        alasan: selected,
      );
    } on ApiException {
      // The shared command gate owns refresh, uncertainty and feedback.
    }
  }

  List<Json> get serviceActive =>
      rows(snapshot?['loket'])
          .expand((room) => rows(room['tiketAktif']))
          .toList();

  Widget connectionStatus() =>
      BlocSelector<StaffQueueBloc, StaffQueueState, String>(
        selector: (state) => state.liveStatus,
        builder: (context, status) {
          final connected = status == 'Realtime terhubung';
          final ink = connected ? const Color(0xff14653b) : QueueBStyle.warning;
          return Tooltip(
            message: status,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 165),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: connected
                    ? const Color(0xffe2f7e9)
                    : const Color(0xfffff3df),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ink.withValues(alpha: .12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connected ? Icons.circle : Icons.sync_rounded,
                    size: connected ? 9 : 15,
                    color: ink,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      connected ? 'Terhubung' : status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> openScheduleDetails() async {
    if (selectedRoom == null || _detailRoute != null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => Theme(
        data: StaffStyle.theme,
        child: AlertDialog(
          title: const Text('Dokter terjadwal'),
          scrollable: true,
          content: SizedBox(
            width: 620,
            child: StaffScheduledDoctors(
              config: widget.api.config,
              schedules: schedules,
              clinic: label(object(selectedRoom?['layanan'])),
              loading: scheduleLoading,
              failed: scheduleFailed,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
    _detailRoute = route;
    _scannerNavigator = navigator;
    try {
      await navigator.push(route);
    } finally {
      if (identical(_detailRoute, route)) _detailRoute = null;
    }
  }

  Widget dashboardHeading(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final staffName = '${widget.api.user?['nama'] ?? ''}'.trim();
      final room = selectedRoom;
      final contextLabel = [
        'Petugas Pelayanan',
        if (room != null) label(object(room['layanan'])),
        if (room?['kode'] != null) '${room!['kode']}',
      ].join(' · ');
      final title = Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: StaffStyle.soft,
            child: Icon(
              Icons.person_outline_rounded,
              color: StaffStyle.blue,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat datang, ${staffName.isEmpty ? 'Petugas' : staffName}',
                  style: const TextStyle(
                    color: StaffStyle.ink,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contextLabel,
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
      final doctor = StaffScheduledDoctorSummary(
        config: widget.api.config,
        schedules: schedules,
        loading: scheduleLoading,
        failed: scheduleFailed,
        onOpen: openScheduleDetails,
      );
      final clock = StaffDashboardClock(config: widget.api.config);
      final refresh = IconButton.outlined(
        tooltip: 'Muat ulang penugasan dan antrean',
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: QueueBStyle.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: const Size(42, 42),
        ),
        onPressed: state.busy || loading ? null : loadAssignments,
        icon: const Icon(
          Icons.refresh_rounded,
          size: 22,
          color: StaffStyle.ink,
        ),
      );
      final normalText = MediaQuery.textScalerOf(context).scale(14) <= 18;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (box.maxWidth >= 980 && normalText)
            Row(
              children: [
                Expanded(flex: 5, child: title),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: doctor),
                const SizedBox(width: 10),
                SizedBox(width: 226, child: clock),
              ],
            )
          else ...[
            title,
            const SizedBox(height: 12),
            if (box.maxWidth >= 620 && normalText)
              Row(
                children: [
                  Expanded(child: doctor),
                  const SizedBox(width: 10),
                  SizedBox(width: 226, child: clock),
                ],
              )
            else ...[
              doctor,
              const SizedBox(height: 8),
              clock,
            ],
          ],
          const SizedBox(height: 12),
          if (box.maxWidth >= 600 && normalText)
            Row(
              children: [
                Expanded(child: roomChoice()),
                const SizedBox(width: 12),
                connectionStatus(),
                const SizedBox(width: 10),
                refresh,
              ],
            )
          else ...[
            roomChoice(),
            const SizedBox(height: 8),
            Row(children: [connectionStatus(), const Spacer(), refresh]),
          ],
        ],
      );
    },
  );

  Widget commandFeedback() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loading)
        const LinearProgressIndicator(semanticsLabel: 'Memuat penugasan'),
      if (state.busy)
        const LinearProgressIndicator(semanticsLabel: 'Memproses tindakan'),
      if (error != null) MobileNotice(error!, error: true),
      QueueBConfirmedFeedback(
        key: const ValueKey('staff-command-feedback'),
        confirmed:
            state.command == StaffCommandStatus.confirmed && message != null,
        child: message == null
            ? const SizedBox.shrink()
            : MobileNotice(
                message!,
                success: state.command == StaffCommandStatus.confirmed,
                popup: true,
              ),
      ),
    ],
  );

  Widget noAssignment() => const StaffPanel(
    title: 'Ruang pelayanan',
    icon: Icons.meeting_room_outlined,
    child: StaffEmpty(
      'Tidak ada penugasan aktif untuk hari ini. Hubungi ADMIN untuk penugasan loket.',
    ),
  );

  Widget desktopPanels(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 54, child: waitingPanel(context, compact: true)),
        const SizedBox(width: 14),
        Expanded(flex: 46, child: servicePanel(context, height: box.maxHeight)),
      ],
    ),
  );

  Widget buildPortal(BuildContext context) => Theme(
    data: StaffStyle.theme,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: widget.headerBuilder?.call(const SizedBox.shrink()),
        backgroundColor: QueueBStyle.background,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              // A bounded desktop column gives the queue and service panels
              // exactly the remaining viewport, without a forced minimum.
              // Small/zoomed views retain scrolling and full text scaling.
              final desktop =
                  box.maxWidth >= 1080 &&
                  box.maxHeight >= 500 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 17.5;
              if (desktop) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dashboardHeading(context),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 76),
                        child: SingleChildScrollView(child: commandFeedback()),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: selectedRoom == null
                            ? Align(
                                alignment: Alignment.topCenter,
                                child: noAssignment(),
                              )
                            : desktopPanels(context),
                      ),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                key: const ValueKey('staff-page-scroll'),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dashboardHeading(context),
                    commandFeedback(),
                    const SizedBox(height: 16),
                    if (selectedRoom == null && !loading) noAssignment(),
                    if (selectedRoom != null) ...[
                      if (box.maxWidth >= 1080 &&
                          MediaQuery.textScalerOf(context).scale(14) <= 18)
                        SizedBox(height: 520, child: desktopPanels(context))
                      else ...[
                        servicePanel(context),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: MediaQuery.textScalerOf(context).scale(540),
                          child: waitingPanel(context),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget queueTabs({bool compact = false}) {
    final followups = patients
        .where((t) => t['status'] == 'CHECK_IN' || t['status'] == 'DILEWATI')
        .length;
    Widget tab(String value, String text, {String? hint}) => Tooltip(
      message: hint ?? text,
      child: ChoiceChip(
        label: Text(text),
        selected: queueTab == value,
        showCheckmark: false,
        selectedColor: StaffStyle.blue,
        backgroundColor: Colors.white,
        materialTapTargetSize: compact
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        side: BorderSide(
          color: queueTab == value ? StaffStyle.blue : QueueBStyle.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          fontSize: compact ? 11 : 12,
          color: queueTab == value ? Colors.white : StaffStyle.ink,
          fontWeight: FontWeight.w600,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 8,
          vertical: compact ? 4 : 8,
        ),
        onSelected: (_) => setState(() => queueTab = value),
      ),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        tab(
          'waiting',
          'Menunggu (${object(snapshot?['menunggu'])['total'] ?? '—'})',
        ),
        tab(
          'active',
          'Dilayani (${snapshot == null ? '—' : serviceActive.length})',
          hint: 'Tiket dipanggil dan sedang dilayani dalam poli ini',
        ),
        Tooltip(
          message: 'Daftar tiket selesai belum tersedia pada data petugas.',
          child: OutlinedButton(
            style: compact
                ? OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
            onPressed: null,
            child: Text(
              'Selesai (—)',
              style: TextStyle(fontSize: compact ? 11 : 12),
            ),
          ),
        ),
        if (followups > 0 ||
            queueTab == 'followup' ||
            (object(snapshot?['daftarPasien'])['jumlahHalamanTindakLanjut'] ??
                    1) >
                1)
          tab(
            'followup',
            'Tindak lanjut ($followups)',
            hint: 'Check-in dan tiket dilewati pada batch yang dimuat',
          ),
      ],
    );
  }

  Widget waitingPanel(BuildContext context, {bool compact = false}) {
    final query = search.text.trim().toLowerCase();
    final source = switch (queueTab) {
      'active' => serviceActive,
      'followup' =>
        patients
            .where(
              (t) => t['status'] == 'CHECK_IN' || t['status'] == 'DILEWATI',
            )
            .toList(),
      _ => patients.where((t) => t['status'] == 'MENUNGGU').toList(),
    };
    final visible = source
        .where(
          (t) => '${t['nomorAntrean'] ?? ''} ${t['namaPasien'] ?? ''}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: QueueBStyle.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final title = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: StaffStyle.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.format_list_bulleted_rounded,
                        color: StaffStyle.blue,
                        size: compact ? 20 : 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Daftar Antrean Poli',
                        style: TextStyle(
                          fontSize: compact ? 16 : 19,
                          fontWeight: FontWeight.w800,
                          color: StaffStyle.ink,
                          letterSpacing: -.3,
                        ),
                      ),
                    ),
                  ],
                );
                return compact && box.maxWidth >= 490
                    ? Row(
                        children: [
                          Expanded(flex: 5, child: title),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 7,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: queueTabs(compact: true),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 8),
                          queueTabs(compact: compact),
                        ],
                      );
              },
            ),
            SizedBox(height: compact ? 8 : 12),
            LayoutBuilder(
              builder: (context, box) {
                final field = TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: compact ? 12 : 14),
                  decoration: InputDecoration(
                    hintText: 'Cari nomor antrean atau nama pasien…',
                    hintStyle: TextStyle(fontSize: compact ? 12 : 14),
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                );
                final qr = OutlinedButton.icon(
                  key: const ValueKey('staff-scan-button'),
                  onPressed: busy || loading || snapshot == null ? null : scan,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: StaffStyle.soft,
                    foregroundColor: StaffStyle.ink,
                    minimumSize: const Size(44, 42),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    textStyle: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text('Pindai QR'),
                );
                return box.maxWidth >= 400
                    ? Row(
                        children: [
                          Expanded(child: field),
                          const SizedBox(width: 10),
                          qr,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [field, const SizedBox(height: 8), qr],
                      );
              },
            ),
            SizedBox(height: compact ? 8 : 12),
            Expanded(
              child: snapshot == null
                  ? const StaffEmpty('Menunggu data antrean…')
                  : StaffPatientList(
                      key: ValueKey('$roomId:$queueTab:$query'),
                      rows: visible,
                      config: widget.api.config,
                      busy: busy,
                      onAction: rowAction,
                      serviceName: label(object(selectedRoom?['layanan'])),
                      compact: compact,
                    ),
            ),
            if (queueTab == 'followup' &&
                (object(
                          snapshot?['daftarPasien'],
                        )['jumlahHalamanTindakLanjut'] ??
                        1) >
                    1)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Batch tindak lanjut: $followupPage/${object(snapshot?['daftarPasien'])['jumlahHalamanTindakLanjut']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tindak lanjut sebelumnya',
                    onPressed: busy || followupPage <= 1
                        ? null
                        : () => bloc.add(StaffPageSelected(followupPage - 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Tindak lanjut berikutnya',
                    onPressed:
                        busy ||
                            followupPage >=
                                (object(
                                      snapshot?['daftarPasien'],
                                    )['jumlahHalamanTindakLanjut'] ??
                                    1)
                        ? null
                        : () => bloc.add(StaffPageSelected(followupPage + 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            const Text(
              'Urutan sesuai server · Pencarian pada data yang dimuat',
              style: TextStyle(fontSize: 11, color: QueueBStyle.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget ticketCard(Json? ticket, {bool compact = false}) => Container(
    padding: EdgeInsets.all(compact ? 10 : 18),
    decoration: BoxDecoration(
      color: const Color(0xfff4f6ff),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: StaffStatusPill(ticket?['status']),
            ),
            SizedBox(height: compact ? 3 : 8),
            QueueBValueMotion(
              value: ticket?['nomorAntrean'],
              scope: selectedRoom?['id'],
              child: Text(
                '${ticket?['nomorAntrean'] ?? '—'}',
                style: TextStyle(
                  color: StaffStyle.ink,
                  fontSize: compact ? 42 : 56,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(height: compact ? 4 : 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(compact ? 5 : 7),
                  decoration: const BoxDecoration(
                    color: Color(0xffe2e7ff),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: StaffStyle.blue,
                    size: compact ? 20 : 25,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ticket == null
                        ? 'Belum ada tiket aktif'
                        : '${ticket['namaPasien'] ?? 'Nama belum tersedia'}',
                    style: TextStyle(
                      color: StaffStyle.ink,
                      fontSize: compact ? 14 : 19,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        Widget fact(IconData icon, String title, String value) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xff41517c), size: compact ? 21 : 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: QueueBStyle.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      color: StaffStyle.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final details = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            fact(
              Icons.medical_services_outlined,
              'Jenis Layanan',
              label(object(selectedRoom?['layanan'])),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 7 : 12),
              child: const Divider(height: 1, color: QueueBStyle.border),
            ),
            fact(
              Icons.access_time_rounded,
              'Waktu Panggil',
              ticket?['dipanggilPada'] == null
                  ? '—'
                  : widget.api.config
                        .instantLabel(ticket?['dipanggilPada'])
                        .split(' ')
                        .last,
            ),
            if (!compact)
              Text(
                widget.api.config.serviceTimeZone,
                style: const TextStyle(fontSize: 11, color: QueueBStyle.muted),
              ),
          ],
        );
        return box.maxWidth >= 380 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: identity),
                  Container(
                    width: 1,
                    height: compact ? 100 : 140,
                    margin: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
                    color: QueueBStyle.border,
                  ),
                  Expanded(flex: 4, child: details),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: QueueBStyle.border),
                  ),
                  details,
                ],
              );
      },
    ),
  );

  Widget serviceButton(
    String text,
    IconData icon,
    String? path, {
    bool complete = false,
    bool compact = false,
  }) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: const Color(0xffc0cef4),
      backgroundColor: complete
          ? const Color(0xff00866e)
          : Colors.white.withValues(alpha: .06),
      disabledBackgroundColor: Colors.white.withValues(alpha: .04),
      side: BorderSide(
        color: complete && path != null
            ? const Color(0xff8ce3cc)
            : const Color(0xffc2d0f9),
      ),
      minimumSize: const Size(44, 42),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 10 : 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: TextStyle(
        fontSize: compact ? 12 : 13,
        fontWeight: FontWeight.w700,
      ),
    ),
    onPressed: busy || path == null ? null : () => action(path),
    icon: Icon(icon, size: compact ? 19 : 22),
    label: path == null ? Text(text) : operationLabel(path, text),
  );

  Widget servicePanel(BuildContext context, {double? height}) => Container(
    height: height,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff2e4b98), Color(0xff14265e)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xff314d95)),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final bounded = box.hasBoundedHeight && active.length <= 1;
        final compact = box.hasBoundedHeight && box.maxHeight < 480;
        final inset = compact ? 12.0 : 16.0;
        final single = active.length == 1 ? active.first : null;
        final startPath = single?['status'] == 'DIPANGGIL'
            ? '/queue/${single?['tiketId']}/mulai-pelayanan'
            : null;
        final primaryPath = startPath ?? '/queue/panggil';
        final primaryEnabled =
            !busy && snapshot != null && (startPath != null || active.isEmpty);
        final banner = Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/illustrations/staff_stethoscope_banner.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                cacheWidth: 1080,
                excludeFromSemantics: true,
                errorBuilder: (_, error, stack) =>
                    const ColoredBox(color: StaffStyle.header),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xe6203874), Color(0x33203874)],
                    stops: [0, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                inset,
                compact ? 10 : 14,
                inset,
                compact ? 8 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.campaign_outlined,
                          color: Colors.white,
                          size: compact ? 20 : 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pelayanan Ruang Ini',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 16 : 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 5 : 8),
                  FractionallySizedBox(
                    widthFactor: .78,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${selectedRoom?['kode'] ?? ''} · ${label(selectedRoom ?? {})}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 13 : 16,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label(object(selectedRoom?['layanan'])),
                    style: TextStyle(
                      color: const Color(0xffd6e2ff),
                      fontSize: compact ? 11 : 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        Widget tickets() {
          if (active.length <= 1)
            return ticketCard(active.firstOrNull, compact: compact);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < active.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                ticketCard(active[i], compact: compact),
              ],
            ],
          );
        }

        Widget controls(Json? ticket) => LayoutBuilder(
          builder: (context, actionsBox) {
            final called = ticket?['status'] == 'DIPANGGIL';
            final serving = ticket?['status'] == 'DILAYANI';
            final separateStart = active.length > 1 && called;
            final buttons = [
              serviceButton(
                'Panggil Ulang',
                Icons.refresh_rounded,
                called ? '/queue/${ticket?['tiketId']}/panggil-ulang' : null,
                compact: compact,
              ),
              serviceButton(
                'Tunda',
                Icons.pause_circle_outline_rounded,
                called ? '/queue/${ticket?['tiketId']}/lewati' : null,
                compact: compact,
              ),
              serviceButton(
                separateStart ? 'Mulai' : 'Selesaikan',
                separateStart ? Icons.play_arrow_rounded : Icons.check_rounded,
                separateStart
                    ? '/queue/${ticket?['tiketId']}/mulai-pelayanan'
                    : serving
                    ? '/queue/${ticket?['tiketId']}/selesaikan-pelayanan'
                    : null,
                complete: true,
                compact: compact,
              ),
            ];
            final columns =
                actionsBox.maxWidth >= 400 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 18
                ? 3
                : 1;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final button in buttons)
                  SizedBox(
                    width: (actionsBox.maxWidth - (columns - 1) * 8) / columns,
                    child: button,
                  ),
              ],
            );
          },
        );
        final actions = Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: primaryEnabled ? () => action(primaryPath) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff5675f3),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xff405baf),
                  disabledForegroundColor: const Color(0xffd1dcff),
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 11 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: TextStyle(
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: Icon(
                  startPath != null
                      ? Icons.play_arrow_rounded
                      : Icons.campaign_outlined,
                  size: compact ? 23 : 27,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: operationLabel(
                        primaryPath,
                        startPath != null
                            ? 'Mulai Pelayanan'
                            : 'Panggil Berikutnya',
                        onLight: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (active.isEmpty) controls(null),
              for (final ticket in active) ...[
                if (active.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${ticket['nomorAntrean']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                controls(ticket),
              ],
              if (!compact) ...[
                const SizedBox(height: 8),
                const Text(
                  'Pemilihan tiket mengikuti prioritas antrean server.',
                  style: TextStyle(color: Color(0xffd6e2ff), fontSize: 11),
                ),
              ],
            ],
          ),
        );
        // A single ticket occupies the flexible middle section. Long names or
        // exceptional multi-active snapshots scroll inside this section only.
        final ticketArea = Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: LayoutBuilder(
            builder: (context, ticketBox) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: ticketBox.hasBoundedHeight
                      ? ticketBox.maxHeight
                      : 0,
                ),
                child: tickets(),
              ),
            ),
          ),
        );
        final content = Column(
          mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            banner,
            const SizedBox(height: 8),
            if (bounded) Expanded(child: ticketArea) else ticketArea,
            const SizedBox(height: 10),
            actions,
          ],
        );
        return bounded || !box.hasBoundedHeight
            ? content
            : SingleChildScrollView(child: content);
      },
    ),
  );

  Widget operationLabel(String path, String text, {bool onLight = false}) {
    if (!state.busy || !path.endsWith('/${state.pending?.route}')) {
      return Text(text);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: onLight ? QueueBStyle.darkTeal : QueueBStyle.mint,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
