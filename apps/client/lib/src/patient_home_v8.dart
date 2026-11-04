import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'app_brand.dart';
import 'api.dart';
import 'config.dart';
import 'features/patient/models/patient_queue_models.dart';
import 'mobile_ui.dart';
import 'patient_design.dart';
import 'patient_home_v7.dart';
import 'patient_reservations.dart' show reservationStatus;
import 'patient_ui.dart';
import 'queueb_interaction_motion.dart';
import 'queueb_value_motion.dart';
import 'user_profile.dart';

abstract final class PatientHomeV8Style {
  static const blue = PatientDesign.primary;
  static const background = Color(0xfff8f9ff);
  static Color accent(PatientServiceCategory category) => switch (category) {
    PatientServiceCategory.registration => blue,
    PatientServiceCategory.pharmacy => const Color(0xff087c70),
    PatientServiceCategory.billing => const Color(0xffb95420),
    PatientServiceCategory.laboratory => const Color(0xffb55149),
    PatientServiceCategory.radiology => const Color(0xff7952b5),
    PatientServiceCategory.medicalRecords => const Color(0xff087f64),
    _ => PatientDesign.primary,
  };
}

/// Public service-hours catalog only. DB TIME is a wall clock, not an instant:
/// extracting HH:mm must not apply an Asia/Jakarta/browser offset a second time.
String patientServiceHours(
  List<Json> rows,
  String serviceId,
  String date, {
  bool available = true,
}) {
  if (!available) return 'Jam belum tersedia';
  final day = DateTime.tryParse(dateOnly(date));
  if (day == null) return 'Jam belum tersedia';
  const weekdays = [
    'SENIN',
    'SELASA',
    'RABU',
    'KAMIS',
    'JUMAT',
    'SABTU',
    'MINGGU',
  ];
  final times = <String>[];
  var hasMatchingSchedule = false;
  for (final row in rows) {
    if (row['aktif'] != true ||
        (row['layananId'] ?? object(row['layanan'])['id']) != serviceId ||
        row['hari'] != weekdays[day.weekday - 1]) {
      continue;
    }
    hasMatchingSchedule = true;
    final open = clockOnly(row['jamBuka']), close = clockOnly(row['jamTutup']);
    bool valid(String value) =>
        RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
    if (valid(open) && valid(close)) {
      times.add('${open.replaceAll(':', '.')}–${close.replaceAll(':', '.')}');
    }
  }
  return times.isEmpty
      ? hasMatchingSchedule
            ? 'Jam belum tersedia'
            : 'Tidak ada jadwal hari ini'
      : (times.toSet().toList()..sort()).join(', ');
}

/// Reads the existing doctor-to-service association and practice schedule.
/// This is a display-only label, not proof that a PETUGAS account is assigned.
/// Never substitute a doctor from a different service or another day.
String? patientServiceScheduledProviderName({
  required List<Json> doctors,
  required List<Json> sessions,
  required String serviceId,
  required String date,
}) {
  final names = <String>{};
  for (final doctor in doctors) {
    if (doctor['aktif'] == false) continue;
    final doctorId = '${doctor['id'] ?? ''}'.trim();
    if (doctorId.isEmpty) continue;
    final links = rows(doctor['dokterLayanan'])
        .where(
          (link) =>
              link['aktif'] == true &&
              (link['layananId'] ?? object(link['layanan'])['id']) == serviceId,
        )
        .toList();
    if (links.isEmpty) continue;

    final scheduled = sessions.any((session) {
      if (session['aktif'] == false ||
          object(session['loket'])['aktif'] == false ||
          dateOnly(session['tanggal']) != date) {
        return false;
      }
      final pair = object(session['dokterLayanan']);
      final providerId = pair['dokterId'] ?? object(pair['dokter'])['id'];
      if (providerId != doctorId) return false;
      final scheduledService =
          pair['layananId'] ?? object(pair['layanan'])['id'];
      if (scheduledService != null && scheduledService != serviceId) {
        return false;
      }
      final pairId = session['dokterLayananId'] ?? pair['id'];
      if (pairId != null) {
        return links.any((link) => link['id'] == pairId);
      }
      // When the schedule does not expose an association ID, accept the
      // explicit service ID, or an unambiguous single active association.
      return scheduledService == serviceId ||
          rows(doctor['dokterLayanan'])
                  .where((l) => l['aktif'] == true)
                  .length ==
              1;
    });
    if (!scheduled) continue;

    final fullName = '${doctor['nama'] ?? ''}'.trim();
    if (fullName.isEmpty) continue;
    names.add(fullName);
  }
  if (names.isEmpty) return null;
  final ordered = names.toList()..sort();
  return ordered.join('\n');
}

/// Fallback for a service with no matching practice session on the selected
/// day. A linked doctor is NOT evidence of an on-duty shift. No cross-service
/// matching and no fabricated names.
String? patientServiceLinkedProviderName({
  required List<Json> doctors,
  required String serviceId,
}) {
  final names = <String>{};
  for (final doctor in doctors) {
    if (doctor['aktif'] == false) continue;
    final links = rows(doctor['dokterLayanan']);
    if (!links.any(
      (link) =>
          link['aktif'] != false &&
          (link['layananId'] ?? object(link['layanan'])['id']) == serviceId,
    )) {
      continue;
    }
    final fullName = '${doctor['nama'] ?? ''}'.trim();
    if (fullName.isNotEmpty) names.add(fullName);
  }
  if (names.isEmpty) return null;
  final sorted = names.toList()..sort();
  return sorted.join('\n');
}

/// Full doctor names for the ticket card, preferring today's practice session
/// before the active doctor-service link. Neither implies an active PETUGAS.
String patientServiceProviderLabel({
  required List<Json> doctors,
  required List<Json> sessions,
  required String serviceId,
  required String date,
}) {
  final scheduled = patientServiceScheduledProviderName(
    doctors: doctors,
    sessions: sessions,
    serviceId: serviceId,
    date: date,
  );
  if (scheduled != null) return scheduled;
  final linked = patientServiceLinkedProviderName(
    doctors: doctors,
    serviceId: serviceId,
  );
  return linked ?? '';
}

/// A single physical paper contour is shared by shadow, clipping and border.
/// The cutouts are actual holes, including hit testing; no background circles.
class PatientTicketClipper extends CustomClipper<Path> {
  const PatientTicketClipper(this.stubWidth);
  final double stubWidth;
  static const notch = 6.0;
  @override
  Path getClip(Size size) {
    final paper = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final cutouts = Path();
    for (final center in [
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Offset(size.width - stubWidth, 0),
      Offset(size.width - stubWidth, size.height),
    ]) {
      cutouts.addOval(Rect.fromCircle(center: center, radius: notch));
    }
    return Path.combine(PathOperation.difference, paper, cutouts);
  }

  @override
  bool shouldReclip(covariant PatientTicketClipper oldClipper) =>
      stubWidth != oldClipper.stubWidth;
}

class _TicketPerforation extends CustomPainter {
  const _TicketPerforation(this.stubWidth, this.color, this.focused);
  final double stubWidth;
  final Color color;
  final bool focused;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .28)
      ..strokeWidth = 1;
    final x = size.width - stubWidth;
    for (double y = 11; y < size.height - 11; y += 8) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + 4, size.height - 11)),
        paint,
      );
    }
    paint
      ..color = focused ? PatientHomeV8Style.blue : color.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = focused ? 2 : 1;
    canvas.drawPath(PatientTicketClipper(stubWidth).getClip(size), paint);
  }

  @override
  bool shouldRepaint(covariant _TicketPerforation oldDelegate) =>
      stubWidth != oldDelegate.stubWidth ||
      color != oldDelegate.color ||
      focused != oldDelegate.focused;
}

class PatientServiceTicketV8 extends StatefulWidget {
  const PatientServiceTicketV8({
    super.key,
    required this.clinic,
    this.ticket,
    this.queue,
    this.hours = 'Jam belum tersedia',
    this.timeZoneLabel = '',
    this.staffName,
    this.onTap,
  });
  final Json clinic;
  final Json? ticket;
  final PatientQueueView? queue;
  final String hours, timeZoneLabel;
  final String? staffName;
  final VoidCallback? onTap;
  @override
  State<PatientServiceTicketV8> createState() => _PatientServiceTicketV8State();
}

class _PatientServiceTicketV8State extends State<PatientServiceTicketV8> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final clinic = widget.clinic;
    final candidate = widget.queue ?? const PatientQueueView();
    final queue =
        candidate.summary == null ||
            candidate.summary!.serviceId == '${clinic['id']}'
        ? candidate
        : const PatientQueueView();
    final summary = queue.summary;
    final scope = (clinic['id'], summary?.date);
    final number = '${widget.ticket?['nomorAntrean'] ?? ''}'.trim();
    final hasTicket = number.isNotEmpty;
    final hasPersonalNumber = hasTicket && number != '—' && number != '-';
    final servingValue = summary?.serving
        .map(
          (entry) => summary.serving.length > 1
              ? '${entry.roomCode}: ${entry.number}'
              : entry.number,
        )
        .join('\n');
    final serving = summary == null
        ? 'Belum tersedia'
        : summary.serving.isEmpty
        ? 'Belum ada pelayanan aktif'
        : servingValue!;
    final staff = widget.staffName?.trim();
    final action = hasTicket ? 'Lihat Status' : 'Ambil Nomor';
    final hours =
        RegExp(r'^\d{2}').hasMatch(widget.hours) &&
            widget.timeZoneLabel.isNotEmpty
        ? '${widget.hours} ${widget.timeZoneLabel}'
        : widget.hours;

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      onTap: widget.onTap,
      label:
          '${label(clinic)}. $hours. '
          '${staff == null || staff.isEmpty ? '' : '$staff. '}'
          '${hasPersonalNumber
              ? 'Nomor antreanmu $number'
              : hasTicket
              ? 'Nomor antreanmu belum tersedia'
              : 'Belum ada tiket untuk hari ini'}. '
          'Sedang dilayani: $serving. '
          '${summary?.waitingCount ?? 'Belum tersedia'} menunggu. '
          '${queue.live ? 'Pembaruan langsung aktif' : 'Pembaruan langsung belum terkonfirmasi'}. '
          '$action.',
      excludeSemantics: true,
      child: QueueBPressMotion(
        enabled: widget.onTap != null,
        builder: (highlight) => LayoutBuilder(
          builder: (context, bounds) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
            final stacked = bounds.maxWidth < 326 || largeText;
            final stubWidth = (bounds.maxWidth * .31).clamp(112.0, 132.0);
            final detailsWidth =
                bounds.maxWidth - (stacked ? 0 : stubWidth) - 24;

            Widget badge(
              String value,
              Color ink,
              Color surface, {
              bool active = false,
              bool fill = false,
              Key? key,
            }) => Container(
              width: fill ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                key: key,
                textAlign: fill ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: active
                      ? (summary!.serving.length > 1 ? 18 : 22)
                      : (bounds.maxWidth >= 480 ? 26 : 22),
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: ink,
                ),
              ),
            );
            Widget field(String title, Widget value, {bool stretch = false}) =>
                Column(
                  crossAxisAlignment: stretch
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: PatientDesign.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    value,
                  ],
                );
            final personal = field(
              'ANTREANMU',
              badge(
                hasTicket ? number : '—',
                hasTicket ? Colors.white : PatientDesign.muted,
                hasTicket ? PatientHomeV8Style.blue : const Color(0xffe5ebf8),
                key: ValueKey('patient-personal-ticket-${clinic['id']}'),
              ),
            );
            final current = field(
              'SEDANG DILAYANI',
              QueueBValueMotion(
                scope: scope,
                available: summary != null,
                value: servingValue,
                child: summary?.serving.isNotEmpty == true
                    ? badge(
                        serving,
                        PatientDesign.statusInk('DILAYANI'),
                        PatientDesign.statusSurface('DILAYANI'),
                        active: true,
                        fill: !hasPersonalNumber,
                        key: ValueKey('patient-serving-${clinic['id']}'),
                      )
                    : Text(
                        serving,
                        key: ValueKey('patient-serving-${clinic['id']}'),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: PatientDesign.muted,
                        ),
                      ),
              ),
              stretch: !hasPersonalNumber,
            );
            final details = Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PatientDesign.soft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.confirmation_number_outlined,
                              size: 13,
                              color: PatientDesign.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Walk-in',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: PatientDesign.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        hours,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: PatientDesign.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label(clinic),
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: PatientDesign.ink,
                    ),
                  ),
                  if (staff != null && staff.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      staff,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: PatientDesign.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xfff5f7ff),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: !hasPersonalNumber
                        ? current
                        : detailsWidth < 176 || largeText
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              personal,
                              const SizedBox(height: 8),
                              current,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: personal),
                              const SizedBox(width: 8),
                              Expanded(child: current),
                            ],
                          ),
                  ),
                  if (summary == null && (queue.loading || queue.error)) ...[
                    const SizedBox(height: 8),
                    Text(
                      queue.freshness,
                      style: const TextStyle(
                        fontSize: 11,
                        color: PatientDesign.muted,
                      ),
                    ),
                  ],
                ],
              ),
            );
            final stub = Container(
              width: stacked ? null : stubWidth,
              padding: const EdgeInsets.all(12),
              color: const Color(0xffeff3ff),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Tooltip(
                    message: 'Jumlah pasien menunggu pada layanan ini',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SISA ANTREAN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: PatientDesign.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        QueueBValueMotion(
                          scope: scope,
                          value: summary?.waitingCount,
                          available: summary?.waitingCount != null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.groups_2_outlined,
                                size: 18,
                                color: PatientDesign.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${summary?.waitingCount ?? '—'}',
                                  key: ValueKey(
                                    'patient-queue-waiting-${clinic['id']}',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: PatientDesign.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'menunggu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: PatientDesign.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: hasTicket
                          ? PatientHomeV8Style.blue
                          : const Color(0xffdae4ff),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            action,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: hasTicket
                                  ? Colors.white
                                  : PatientDesign.primary,
                            ),
                          ),
                        ),
                        if (stacked || stubWidth >= 124) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: hasTicket
                                ? Colors.white
                                : PatientDesign.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
            final content = stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [details, stub],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: details),
                        stub,
                      ],
                    ),
                  );
            final ink = Material(
              color: Colors.white,
              shape: stacked
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _focused
                            ? PatientHomeV8Style.blue
                            : PatientDesign.border,
                        width: _focused ? 2 : 1,
                      ),
                    )
                  : null,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: highlight,
                onFocusChange: (focused) => setState(() => _focused = focused),
                focusColor: PatientHomeV8Style.blue.withValues(alpha: .12),
                child: content,
              ),
            );
            if (stacked) return ink;
            return PhysicalShape(
              clipper: PatientTicketClipper(stubWidth),
              color: Colors.white,
              elevation: _focused ? 2 : 1,
              shadowColor: const Color(0x18172544),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                foregroundPainter: _TicketPerforation(
                  stubWidth,
                  PatientHomeV8Style.blue,
                  _focused,
                ),
                child: ink,
              ),
            );
          },
        ),
      ),
    );
  }
}

class PatientHomeAppBarV8 extends StatelessWidget
    implements PreferredSizeWidget {
  const PatientHomeAppBarV8({
    super.key,
    required this.api,
    required this.height,
    required this.onProfile,
    required this.onNotifications,
    this.maxWidth = 680,
  });
  final QueueApi api;
  final double height, maxWidth;
  final VoidCallback onProfile, onNotifications;
  static double heightFor(BuildContext context) => math.max(
    64,
    MediaQuery.textScalerOf(context).scale(16) *
            (MediaQuery.textScalerOf(context).scale(12) > 18 ? 4 : 3) +
        16,
  );
  @override
  Size get preferredSize => Size.fromHeight(height);
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListenableBuilder(
            listenable: api,
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    label: AppBrand.name,
                    child: const ExcludeSemantics(
                      child: QueueBBrand(
                        compact: true,
                        fontSize: 16,
                        logoSize: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Notifikasi',
                  onPressed: onNotifications,
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: PatientHomeV8Style.blue,
                    size: 22,
                  ),
                ),
                IconButton(
                  tooltip: 'Profil pasien',
                  onPressed: onProfile,
                  icon: ExcludeSemantics(
                    child: AccountAvatar(api: api, radius: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PatientHomeWelcomeV8 extends StatelessWidget {
  const PatientHomeWelcomeV8({
    super.key,
    required this.name,
    required this.now,
    required this.controller,
    required this.onSearch,
    this.appointmentMode = false,
  });
  final String name;
  final DateTime now;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final bool appointmentMode;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: PatientDesign.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${name.trim().isEmpty ? 'Pasien' : name.trim()}',
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: PatientDesign.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        AppBrand.name,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: PatientDesign.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PatientDesign.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      size: 24,
                      color: PatientHomeV8Style.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onSearch,
          style: const TextStyle(fontSize: 14, color: PatientDesign.ink),
          decoration: InputDecoration(
            isDense: true,
            constraints: const BoxConstraints(minHeight: 48),
            hintText: appointmentMode
                ? 'Cari nama dokter atau spesialisasi...'
                : 'Cari layanan, poli, atau dokter...',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: PatientDesign.muted,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 48,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 22,
              color: PatientDesign.muted,
            ),
            filled: true,
            fillColor: Colors.white,
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
                width: 1.5,
              ),
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Bersihkan pencarian',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      onSearch('');
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class PatientHomeVisitV8 extends StatelessWidget {
  const PatientHomeVisitV8({
    super.key,
    required this.config,
    this.ticket,
    this.appointment,
    this.onOpen,
    this.loading = false,
    this.unavailable = false,
  });
  final AppConfig config;
  final Json? ticket, appointment;
  final VoidCallback? onOpen;
  final bool loading, unavailable;
  @override
  Widget build(BuildContext context) {
    final slot = object(appointment?['slotPraktik']);
    final day =
        '${ticket?['tanggalPelayanan'] ?? ticket?['tanggalAntrean'] ?? ''}';
    final service = label(object(ticket?['layanan']));
    final number = '${ticket?['nomorAntrean'] ?? ''}'.trim();
    final when = ticket == null
        ? loading
              ? 'Memuat kunjungan…'
              : unavailable
              ? 'Kunjungan belum dapat dimuat.'
              : 'Belum ada kunjungan mendatang.'
        : [
            dateOnly(day) == config.today
                ? 'Hari ini'
                : patientCompactDate(day),
            if (slot['mulaiPada'] != null)
              '${patientTime(slot, config)} ${patientHomeTimeZone(config.serviceTimeZone)}',
            if (number.isNotEmpty) 'No. $number',
          ].join(' · ');
    final status = ticket == null
        ? null
        : reservationStatus('${ticket!['status']}');
    return Material(
      key: const ValueKey('patient-nearest-visit'),
      color: const Color(0xffdbe5ff),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: PatientHomeV8Style.blue,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'KUNJUNGAN TERDEKAT',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: PatientHomeV8Style.blue,
                            ),
                          ),
                          if (ticket != null &&
                              service.isNotEmpty &&
                              service != '—')
                            Text(
                              service,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: PatientDesign.ink,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: when),
                            if (status != null)
                              TextSpan(
                                text: ' · $status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: PatientDesign.statusInk(
                                    '${ticket!['status']}',
                                  ),
                                ),
                              ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: PatientDesign.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onOpen != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: PatientHomeV8Style.blue,
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PatientHomeListHeading extends StatelessWidget {
  const PatientHomeListHeading({
    super.key,
    required this.title,
    this.caption,
    this.live = false,
    this.showLive = false,
  });
  final String title;
  final String? caption;
  final bool live, showLive;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: PatientDesign.ink,
        ),
      ),
      if (caption != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xffe4ebff),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            caption!,
            style: const TextStyle(
              fontSize: 11,
              height: 1.3,
              color: PatientDesign.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      if (showLive)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              live ? Icons.circle : Icons.sync_rounded,
              size: live ? 7 : 14,
              color: live
                  ? PatientDesign.statusInk('DILAYANI')
                  : PatientDesign.muted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                live ? 'Live Update' : 'Pembaruan berkala',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: live
                      ? PatientDesign.statusInk('DILAYANI')
                      : PatientDesign.muted,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

class PatientHomeOtherSchedules extends StatelessWidget {
  const PatientHomeOtherSchedules({super.key, this.onOpen});
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: PatientDesign.soft,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.event_available_outlined,
                color: PatientHomeV8Style.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cari jadwal di hari lain',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: PatientDesign.ink,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Pilih dokter dan tanggal praktik.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: PatientDesign.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: PatientHomeV8Style.blue,
            ),
          ],
        ),
      ),
    ),
  );
}

String patientHomeTimeZone(String zone) => switch (zone) {
  'Asia/Jakarta' => 'WIB',
  'Asia/Makassar' => 'WITA',
  'Asia/Jayapura' => 'WIT',
  _ => zone,
};
