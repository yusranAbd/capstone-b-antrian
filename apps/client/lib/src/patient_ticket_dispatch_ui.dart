import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'features/patient/models/patient_queue_models.dart';
import 'patient_design.dart';

/// Presentation only. Position and ahead must come from the owned-ticket API.
class PatientTicketDispatchPanel extends StatelessWidget {
  const PatientTicketDispatchPanel({
    super.key,
    this.position,
    this.ahead,
    this.serving = const [],
    required this.checkInLabel,
    this.checkInVerified = false,
    this.loading = false,
    this.failed = false,
    this.live = false,
    this.updatedLabel,
  });

  final int? position, ahead;
  final List<PatientServingNumber> serving;
  final String checkInLabel;
  final bool checkInVerified, loading, failed, live;
  final String? updatedLabel;

  @override
  Widget build(BuildContext context) {
    final actualPosition = position != null && position! >= 1 ? position : null;
    final actualAhead = ahead != null && ahead! >= 0 ? ahead : null;
    final updated = updatedLabel?.trim() ?? '';
    final hasData =
        actualPosition != null ||
        actualAhead != null ||
        serving.isNotEmpty ||
        updated.isNotEmpty;
    final connected = live && !loading && !failed;
    final verifiedLive =
        connected && actualPosition != null && actualAhead != null;
    final freshness = loading
        ? 'Memuat'
        : verifiedLive
        ? 'REALTIME'
        : connected
        ? 'Terhubung'
        : hasData
        ? 'Data terakhir'
        : 'Belum tersedia';
    final checkInTime = checkInLabel.trim();
    final checkIn = checkInVerified
        ? checkInTime.isEmpty || checkInTime == '—'
              ? 'Terverifikasi'
              : 'Terverifikasi ($checkInTime)'
        : checkInTime.isEmpty || checkInTime == '—'
        ? loading
              ? 'Memuat verifikasi…'
              : 'Verifikasi belum tersedia'
        : checkInTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: PatientDesign.soft,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connected
                        ? Icons.wifi_rounded
                        : loading
                        ? Icons.sync_rounded
                        : Icons.history_rounded,
                    size: 12,
                    color: PatientDesign.primary,
                  ),
                  const SizedBox(width: 4),
                  const Flexible(
                    child: Text(
                      'STATUS DISPATCH ANTREAN',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .3,
                        color: PatientDesign.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: PatientDesign.paper,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  freshness,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: verifiedLive
                        ? PatientDesign.primary
                        : PatientDesign.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, bounds) {
            final own = _DispatchCountCard(
              label: 'URUTAN ANDA',
              count: actualPosition,
              caption: 'Giliran panggilan',
              primary: true,
            );
            final before = _DispatchCountCard(
              label: 'DI DEPAN ANDA',
              count: actualAhead,
              caption: 'Orang menunggu',
            );
            if (bounds.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(12) > 17) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [own, const SizedBox(height: 6), before],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: own),
                const SizedBox(width: 6),
                Expanded(child: before),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PatientDesign.soft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DispatchInfoRow(
                label: 'Sedang Dilayani',
                icon: Icons.desktop_windows_outlined,
                value: serving.isEmpty
                    ? 'Belum tersedia'
                    : serving
                          .map((item) => '${item.roomCode} [${item.number}]')
                          .join('\n'),
              ),
              const SizedBox(height: 4),
              _DispatchInfoRow(
                label: 'Check-in',
                icon: checkInVerified
                    ? Icons.verified_outlined
                    : Icons.fact_check_outlined,
                value: checkIn,
                color: checkInVerified
                    ? PatientDesign.success
                    : PatientDesign.muted,
              ),
            ],
          ),
        ),
        if (updated.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Pembaruan terakhir: $updated',
            style: const TextStyle(
              fontSize: 10,
              height: 1.35,
              color: PatientDesign.muted,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PatientDesign.statusSurface('MENUNGGU')
                .withValues(alpha: .55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: PatientDesign.warning,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Urutan mengikuti antrean setelah check-in, bukan nomor tiket. '
                  'Posisi dapat berubah sesuai kondisi antrean.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: PatientDesign.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DispatchCountCard extends StatelessWidget {
  const _DispatchCountCard({
    required this.label,
    required this.count,
    required this.caption,
    this.primary = false,
  });

  final String label, caption;
  final int? count;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ink = primary ? PatientDesign.paper : PatientDesign.ink;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: primary ? PatientDesign.primary : PatientDesign.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == null ? '—' : count.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == null ? 'Posisi belum tersedia' : caption,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.3, color: ink),
          ),
        ],
      ),
    );
  }
}

class _DispatchInfoRow extends StatelessWidget {
  const _DispatchInfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.color = PatientDesign.ink,
  });

  final String label, value;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final title = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 14, color: PatientDesign.muted),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: PatientDesign.muted,
              ),
            ),
          ),
        ],
      );
      final detail = Text(
        value,
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      );
      if (bounds.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(12) > 17) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 2), detail],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: title),
          const SizedBox(width: 6),
          Expanded(child: detail),
        ],
      );
    },
  );
}

/// Decorative ticket perforation; the surrounding surface can match its notches.
class PatientTicketSeparator extends StatelessWidget {
  const PatientTicketSeparator({
    super.key,
    this.color = PatientDesign.border,
    this.notchColor = PatientDesign.background,
  });

  final Color color, notchColor;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: double.infinity,
      height: 12,
      child: ClipRect(
        child: CustomPaint(
          painter: _TicketSeparatorPainter(
            color: color,
            notchColor: notchColor,
          ),
        ),
      ),
    ),
  );
}

class _TicketSeparatorPainter extends CustomPainter {
  const _TicketSeparatorPainter({
    required this.color,
    required this.notchColor,
  });
  final Color color, notchColor;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    final middle = size.height / 2;
    final right = size.width - 8;
    for (var x = 8.0; x < right; x += 9) {
      canvas.drawLine(
        Offset(x, middle),
        Offset(x + 5 < right ? x + 5 : right, middle),
        line,
      );
    }
    final cutout = Paint()..color = notchColor;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final edge in [0.0, size.width]) {
      canvas.drawCircle(Offset(edge, middle), 5, cutout);
      canvas.drawCircle(Offset(edge, middle), 5, outline);
    }
  }

  @override
  bool shouldRepaint(covariant _TicketSeparatorPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.notchColor != notchColor;
}
