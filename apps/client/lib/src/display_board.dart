import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'mobile_ui.dart';
import 'queueb_motion.dart';
import 'queueb_value_motion.dart';

/// Renders only the allowlisted, privacy-filtered display snapshot.
class DisplayBoard extends StatelessWidget {
  const DisplayBoard({
    super.key,
    required this.snapshot,
    required this.now,
    required this.status,
    required this.onRefresh,
    required this.onAudio,
    required this.onConfigure,
    required this.onFullscreen,
    this.error,
    this.audioError,
    this.audio = false,
    this.audioBusy = false,
    this.fullscreen = false,
    this.fullscreenSupported = false,
    this.rejected = false,
    this.snapshotTime,
    this.clock,
  });
  final Json? snapshot;
  final DateTime now;
  final ValueListenable<DateTime>? clock;
  final String status;
  final String? error, audioError, snapshotTime;
  final bool audio, audioBusy, fullscreen, fullscreenSupported, rejected;
  final VoidCallback onRefresh, onAudio, onConfigure, onFullscreen;

  bool get live => status == 'Realtime terhubung';
  List<Json> get rooms => rows(snapshot?['loket']);

  static ({Json room, Json ticket})? currentCall(Json? snapshot) {
    final active = <({Json room, Json ticket})>[
      for (final room in rows(snapshot?['loket']))
        for (final ticket in rows(room['tiketAktif']))
          if (ticket['status'] == 'DIPANGGIL' || ticket['status'] == 'DILAYANI')
            (room: room, ticket: ticket),
    ];
    // New calls take priority; START must not clear a still-active ticket.
    final hasCall = active.any(
      (entry) => entry.ticket['status'] == 'DIPANGGIL',
    );
    final calls = active
        .where((entry) => !hasCall || entry.ticket['status'] == 'DIPANGGIL')
        .toList();
    final announcement = object(snapshot?['pengumumanTerakhir']);
    for (final call in calls) {
      if (call.room['kode'] == announcement['kodeLoket'] &&
          call.ticket['nomorAntrean'] == announcement['nomorAntrean']) {
        return call;
      }
    }
    calls.sort((a, b) {
      final left = DateTime.tryParse('${a.ticket['dipanggilPada']}');
      final right = DateTime.tryParse('${b.ticket['dipanggilPada']}');
      return (right?.millisecondsSinceEpoch ?? 0).compareTo(
        left?.millisecondsSinceEpoch ?? 0,
      );
    });
    return calls.firstOrNull;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      // Portrait is a scaled monitor preview; the monitor itself never scrolls.
      if (bounds.maxWidth < 900 || bounds.maxHeight < 500) {
        return ColoredBox(
          color: QueueBStyle.background,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1280,
                height: 720,
                child: _monitor(context, const Size(1280, 720)),
              ),
            ),
          ),
        );
      }
      return _monitor(context, bounds.biggest);
    },
  );

  Widget _monitor(BuildContext context, Size size) {
    final unit = math.min(size.width / 1672, size.height / 941);
    return CustomPaint(
      painter: const _DisplayBackdrop(),
      child: Padding(
        padding: EdgeInsets.all(28 * unit),
        child: Column(
          children: [
            _header(unit),
            SizedBox(height: 32 * unit),
            if (error != null || rejected) _connection(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 58, child: _hero(unit)),
                  SizedBox(width: 20 * unit),
                  Expanded(flex: 42, child: _waiting(unit)),
                ],
              ),
            ),
            _controls(unit),
          ],
        ),
      ),
    );
  }

  Widget _header(double unit) {
    final connected = live && error == null && !rejected;
    final statusInk = connected
        ? const Color(0xff06784d)
        : rejected
        ? QueueBStyle.danger
        : QueueBStyle.warning;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 28 * unit, vertical: 14 * unit),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28 * unit),
        border: Border.all(color: QueueBStyle.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121e468e),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 262 * unit,
            child: Row(
              children: [
                Container(
                  width: 72 * unit,
                  height: 72 * unit,
                  decoration: BoxDecoration(
                    color: const Color(0xff315ddb),
                    borderRadius: BorderRadius.circular(20 * unit),
                  ),
                  child: Icon(
                    Icons.local_hospital_rounded,
                    size: 52 * unit,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16 * unit),
                Expanded(
                  child: Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(
                          text: 'QueueB\n',
                          style: TextStyle(color: Color(0xff101e4a)),
                        ),
                        TextSpan(
                          text: 'Hospital',
                          style: TextStyle(color: Color(0xff315ddb)),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 42 * unit,
                      height: .98,
                      letterSpacing: -.8 * unit,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 24 * unit),
          Container(
            width: 1,
            height: 78 * unit,
            color: const Color(0xffcbd7fa),
          ),
          SizedBox(width: 32 * unit),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${object(rejected ? null : snapshot?['layanan'])['nama'] ?? 'Public Display'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 44 * unit,
                    height: 1.1,
                    letterSpacing: -.7 * unit,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff101e4a),
                  ),
                ),
                SizedBox(height: 7 * unit),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16 * unit,
                      vertical: 7 * unit,
                    ),
                    decoration: BoxDecoration(
                      color: connected
                          ? const Color(0xffdef4ea)
                          : statusInk.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(16 * unit),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          connected
                              ? Icons.sensors_rounded
                              : Icons.sensors_off_rounded,
                          size: 25 * unit,
                          color: statusInk,
                        ),
                        SizedBox(width: 10 * unit),
                        Flexible(
                          child: Text(
                            rejected ? 'Akses ditolak' : status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 21 * unit,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: statusInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 24 * unit),
          if (clock == null)
            _clock(now, unit)
          else
            ValueListenableBuilder<DateTime>(
              valueListenable: clock!,
              builder: (_, value, _) => _clock(value, unit),
            ),
        ],
      ),
    );
  }

  Widget _clock(DateTime value, double unit) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}',
        key: const ValueKey('display-clock'),
        style: TextStyle(
          fontSize: 52 * unit,
          height: 1.05,
          letterSpacing: -.6 * unit,
          fontWeight: FontWeight.w800,
          color: const Color(0xff101e4a),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      SizedBox(height: 5 * unit),
      Text(
        _date(value),
        style: TextStyle(
          fontSize: 24 * unit,
          height: 1.2,
          color: QueueBStyle.muted,
        ),
      ),
    ],
  );

  Widget _connection() => MobileNotice(
    error ??
        (rejected
            ? 'Akses display ditolak · periksa konfigurasi perangkat'
            : snapshot == null
            ? 'Koneksi terganggu · menunggu data antrean'
            : 'Snapshot belum tersinkron · menampilkan data terakhir'),
    error: true,
  );

  Widget _hero(double unit) {
    final visibleSnapshot = rejected ? null : snapshot;
    final call = currentCall(visibleSnapshot);
    final serving = call?.ticket['status'] == 'DILAYANI';
    final announcement = object(visibleSnapshot?['pengumumanTerakhir']);
    final name = call?.ticket['namaPasien'];
    return QueueBValueMotion(
      value: (
        call?.room['kode'],
        call?.ticket['nomorAntrean'],
        call?.ticket['status'],
        announcement['peristiwaId'],
      ),
      scope: (
        object(visibleSnapshot?['layanan'])['kode'],
        visibleSnapshot?['tanggalPelayanan'],
      ),
      available: visibleSnapshot != null,
      highlight: true,
      animateChild: false,
      borderOnly: true,
      radius: 28 * unit,
      highlightColor: QueueBStyle.mint,
      child: Container(
        key: const ValueKey('display-call-panel'),
        padding: EdgeInsets.all(26 * unit),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff3063d6), Color(0xff2855c7)],
          ),
          borderRadius: BorderRadius.circular(28 * unit),
          border: Border.all(color: const Color(0xff3968df)),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: Colors.white, fontSize: 24 * unit),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    serving
                        ? Icons.medical_services_outlined
                        : Icons.campaign_outlined,
                    color: Colors.white,
                    size: 48 * unit,
                  ),
                  SizedBox(width: 16 * unit),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 22 * unit,
                        vertical: 10 * unit,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(22 * unit),
                      ),
                      child: Text(
                        call == null
                            ? 'INFORMASI PANGGILAN'
                            : serving
                            ? 'SEDANG DILAYANI'
                            : 'SEDANG DIPANGGIL',
                        style: TextStyle(
                          fontSize: 30 * unit,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2 * unit,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (call != null) ...[
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: QueueBValueMotion(
                        value: (call.room['kode'], call.ticket['nomorAntrean']),
                        scope: (
                          object(visibleSnapshot?['layanan'])['kode'],
                          visibleSnapshot?['tanggalPelayanan'],
                        ),
                        available: visibleSnapshot != null,
                        duration: QueueBMotion.display,
                        child: Text(
                          '${call.ticket['nomorAntrean']}',
                          key: const ValueKey('display-call-number'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 420 * unit,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -6 * unit,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (name is String && name.trim().isNotEmpty)
                  Text(
                    name,
                    key: const ValueKey('display-call-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 56 * unit,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                SizedBox(height: 24 * unit),
                Container(
                  key: const ValueKey('display-call-destination'),
                  padding: EdgeInsets.symmetric(
                    horizontal: 24 * unit,
                    vertical: 16 * unit,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff17377c), Color(0xff1c3c85)],
                    ),
                    borderRadius: BorderRadius.circular(26 * unit),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        color: Colors.white,
                        size: 60 * unit,
                      ),
                      Container(
                        width: 1,
                        height: 76 * unit,
                        color: const Color(0xffb8cbff),
                        margin: EdgeInsets.symmetric(horizontal: 28 * unit),
                      ),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Loket ${call.room['kode'] ?? '—'}',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 44 * unit,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 4 * unit),
                            Text(
                              '${call.room['nama'] ?? '—'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 32 * unit,
                                height: 1.1,
                                color: const Color(0xffd3e0ff),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (visibleSnapshot == null &&
                            !rejected &&
                            error == null) ...[
                          const CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 18 * unit),
                        ],
                        Text(
                          rejected
                              ? 'Akses display ditolak'
                              : visibleSnapshot == null
                              ? error == null
                                    ? 'Memuat antrean…'
                                    : 'Menunggu koneksi'
                              : 'Belum ada nomor dipanggil.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 44 * unit,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 16 * unit),
                        Text(
                          'Perhatikan layar dan dengarkan panggilan petugas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24 * unit,
                            height: 1.3,
                            color: const Color(0xffe4edff),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _waiting(double unit) => _PatientQueue(
    key: ValueKey((
      object(snapshot?['layanan'])['kode'],
      snapshot?['tanggalPelayanan'],
      rejected,
    )),
    snapshot: rejected ? null : snapshot,
    unit: unit,
    rejected: rejected,
    failed: error != null,
  );

  Widget _controls(double unit) => Padding(
    padding: EdgeInsets.only(top: 8 * unit),
    child: TextButtonTheme(
      data: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xff2451cf),
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.symmetric(
            horizontal: 12 * unit,
            vertical: 8 * unit,
          ),
          textStyle: TextStyle(
            fontSize: 18 * unit,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10 * unit),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (audioError != null) MobileNotice(audioError!, error: true),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8 * unit,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [
                if (!rejected) ...[
                  TextButton.icon(
                    onPressed: audioBusy ? null : onAudio,
                    icon: Icon(
                      audio
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_outlined,
                      size: 25 * unit,
                    ),
                    label: Text(audio ? 'Matikan suara' : 'Aktifkan suara'),
                  ),
                  _controlDivider(unit),
                  TextButton.icon(
                    onPressed: onRefresh,
                    icon: Icon(Icons.refresh_rounded, size: 25 * unit),
                    label: const Text('Muat ulang'),
                  ),
                  _controlDivider(unit),
                ],
                if (fullscreenSupported) ...[
                  TextButton.icon(
                    onPressed: onFullscreen,
                    icon: Icon(
                      fullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      size: 25 * unit,
                    ),
                    label: Text(
                      fullscreen ? 'Keluar layar penuh' : 'Layar penuh',
                    ),
                  ),
                  _controlDivider(unit),
                ],
                TextButton.icon(
                  onPressed: onConfigure,
                  icon: Icon(Icons.settings_outlined, size: 25 * unit),
                  label: const Text('Ganti perangkat'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _controlDivider(double unit) =>
      Container(width: 1, height: 28 * unit, color: const Color(0xffd3dcf7));
}

class _DisplayBackdrop extends CustomPainter {
  const _DisplayBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfff1f5ff), Color(0xffeaf0ff), Color(0xfff8faff)],
        ).createShader(Offset.zero & size),
    );
    final wave = Path()
      ..moveTo(0, size.height * .94)
      ..cubicTo(
        size.width * .18,
        size.height * .86,
        size.width * .25,
        size.height * 1.08,
        size.width * .55,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0x99dae5ff));
    final right = Path()
      ..moveTo(size.width * .7, size.height)
      ..quadraticBezierTo(
        size.width * .88,
        size.height * .97,
        size.width,
        size.height * .88,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(right, Paint()..color = const Color(0x99e4ebff));
  }

  @override
  bool shouldRepaint(covariant _DisplayBackdrop oldDelegate) => false;
}

/// Read-only patient list. Paging includes skipped tickets without changing CALL order.
class _PatientQueue extends StatefulWidget {
  const _PatientQueue({
    super.key,
    required this.snapshot,
    required this.unit,
    this.rejected = false,
    this.failed = false,
  });
  final Json? snapshot;
  final double unit;
  final bool rejected, failed;
  @override
  State<_PatientQueue> createState() => _PatientQueueState();
}

class _PatientQueueState extends State<_PatientQueue> {
  int page = 0, pagesAvailable = 1;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && pagesAvailable > 1) setState(() => page++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot, unit = widget.unit;
    final patients = snapshot?['antrianPasien'] is List
        ? rows(snapshot?['antrianPasien'])
        : [
            for (final row in rows(snapshot?['menunggu']))
              {...row, 'status': 'MENUNGGU'},
          ];
    final rawTotal =
        snapshot?['totalAntrianPasien'] ?? snapshot?['totalMenunggu'];
    final total = rawTotal is num
        ? rawTotal.toInt()
        : int.tryParse('$rawTotal');
    return Container(
      key: const ValueKey('display-waiting-panel'),
      padding: EdgeInsets.all(20 * unit),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28 * unit),
        border: Border.all(color: QueueBStyle.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x071e468e),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final rowWidth = math.max(0.0, box.maxWidth - 36 * unit);
          final numberWidth = rowWidth * .24;
          final statusWidth = rowWidth * .34;
          final fontScale =
              MediaQuery.textScalerOf(context).scale(28 * unit) / (28 * unit);
          final rowHeight = math.max(
            84 * unit,
            MediaQuery.textScalerOf(context).scale(28 * unit) * 2.2 + 20 * unit,
          );
          final rowGap = 14 * unit;
          Widget status(Json row) {
            final skipped = row['status'] == 'DILEWATI';
            final waiting = row['status'] == 'MENUNGGU';
            final ink = skipped ? QueueBStyle.warning : const Color(0xff2449b7);
            return Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14 * unit,
                  vertical: 8 * unit,
                ),
                decoration: BoxDecoration(
                  color: skipped
                      ? const Color(0xfffff0d8)
                      : const Color(0xffe2eaff),
                  borderRadius: BorderRadius.circular(18 * unit),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      skipped
                          ? Icons.pause_circle_outline_rounded
                          : Icons.schedule_rounded,
                      size: 25 * unit,
                      color: ink,
                    ),
                    SizedBox(width: 8 * unit),
                    Flexible(
                      child: Text(
                        skipped
                            ? 'Dilewati'
                            : waiting
                            ? 'Menunggu'
                            : '—',
                        style: TextStyle(
                          fontSize: 22 * unit,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: const Color(0xff2f58d4),
                    size: 48 * unit,
                  ),
                  SizedBox(width: 16 * unit),
                  Expanded(
                    child: Text(
                      'Antrean pasien',
                      style: TextStyle(
                        fontSize: 38 * unit,
                        height: 1.15,
                        letterSpacing: -.4 * unit,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff101e4a),
                      ),
                    ),
                  ),
                  SizedBox(width: 12 * unit),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20 * unit,
                      vertical: 8 * unit,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffe3eaff),
                      borderRadius: BorderRadius.circular(20 * unit),
                    ),
                    child: Text(
                      '${total ?? '—'}',
                      key: const ValueKey('display-waiting-count'),
                      style: TextStyle(
                        fontSize: 46 * unit,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff2f58d4),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24 * unit),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 18 * unit,
                  vertical: 16 * unit,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffebf0ff),
                  borderRadius: BorderRadius.circular(18 * unit),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 22 * unit,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: QueueBStyle.muted,
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: numberWidth, child: const Text('NOMOR')),
                      const Expanded(child: Text('NAMA PASIEN')),
                      SizedBox(
                        width: statusWidth,
                        child: const Text(
                          'STATUS',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: rowGap),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    if (patients.isEmpty) {
                      pagesAvailable = 1;
                      return Center(
                        child: Text(
                          widget.rejected
                              ? 'Akses display ditolak.'
                              : snapshot == null
                              ? widget.failed
                                    ? 'Menunggu koneksi…'
                                    : 'Memuat antrean…'
                              : total == 0
                              ? 'Belum ada antrean pasien.'
                              : 'Daftar pasien belum tersedia.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26 * unit,
                            height: 1.3,
                            color: QueueBStyle.muted,
                          ),
                        ),
                      );
                    }
                    final footerHeight = 44 * unit * fontScale;
                    final capacity = math.max(
                      1,
                      ((bounds.maxHeight - footerHeight + rowGap) /
                              (rowHeight + rowGap))
                          .floor(),
                    );
                    final pages = (patients.length / capacity).ceil();
                    pagesAvailable = pages;
                    final currentPage = page % pages;
                    final shown = patients
                        .skip(currentPage * capacity)
                        .take(capacity)
                        .toList();
                    final remaining = math.max(
                      0,
                      (total ?? patients.length) - patients.length,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          if (i > 0) SizedBox(height: rowGap),
                          SizedBox(
                            height: rowHeight,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18 * unit,
                                vertical: 9 * unit,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xfff3f6ff),
                                borderRadius: BorderRadius.circular(18 * unit),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: numberWidth,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${shown[i]['nomorAntrean'] ?? '—'}',
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 34 * unit,
                                            height: 1.1,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xff101e4a),
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: 10 * unit,
                                      ),
                                      child: Text(
                                        '${shown[i]['namaPasien'] ?? '—'}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 28 * unit,
                                          height: 1.1,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xff101e4a),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: statusWidth,
                                    child: status(shown[i]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (pages > 1 || remaining > 0)
                          SizedBox(
                            height: footerHeight,
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                '${currentPage + 1}/$pages · ${total ?? patients.length} antrean${remaining > 0 ? ' · $remaining antrean belum ditampilkan' : ''}',
                                key: const ValueKey('display-more-waiting'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 16 * unit,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: QueueBStyle.muted,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _date(DateTime date) {
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
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}
