import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_brand.dart';
import 'mobile_ui.dart';
import 'patient_design.dart';

/// Presentation only; the booking page continues to own navigation and scope.
class PatientDoctorDetailHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const PatientDoctorDetailHeader({
    super.key,
    required this.onBack,
    this.height = 60,
    this.onProfile,
    this.avatar,
  });

  final VoidCallback? onBack, onProfile;
  final Widget? avatar;
  final double height;

  static double heightFor(BuildContext context) =>
      math.max(60, MediaQuery.textScalerOf(context).scale(16) * 2.4 + 12);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final scaledTitle = MediaQuery.textScalerOf(context).scale(16);
              final fullBrand = bounds.maxWidth >= 560 && scaledTitle <= 25;
              final compactMark =
                  !fullBrand && bounds.maxWidth >= 320 && scaledTitle <= 25;
              return Row(
                children: [
                  IconButton(
                    tooltip: 'Kembali',
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: PatientDesign.ink,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 24),
                  ),
                  const SizedBox(width: 4),
                  if (fullBrand) ...[
                    const SizedBox(
                      width: 196,
                      child: QueueBBrand(
                        compact: true,
                        fontSize: 17,
                        logoSize: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ] else if (compactMark) ...[
                    const _PatientDoctorBrandMark(),
                    const SizedBox(width: 10),
                  ],
                  const Expanded(
                    child: Text(
                      'Detail Dokter',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: PatientDesign.ink,
                      ),
                    ),
                  ),
                  if (onProfile != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Profil pasien',
                      onPressed: onProfile,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: PatientDesign.primary,
                      ),
                      icon: avatar == null
                          ? const Icon(Icons.person_outline_rounded, size: 24)
                          : ExcludeSemantics(child: avatar!),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Reuses the original brand mark while omitting its wordmark on narrow pages.
class _PatientDoctorBrandMark extends StatelessWidget {
  const _PatientDoctorBrandMark();

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppBrand.name,
    image: true,
    child: const ExcludeSemantics(
      child: SizedBox(
        width: 30,
        height: 30,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 220,
            maxWidth: 220,
            child: QueueBBrand(compact: true, logoSize: 30, fontSize: 17),
          ),
        ),
      ),
    ),
  );
}

/// Place in the shell footer so the content reserves space for this bar.
/// Selection validity and mutation guards remain the caller's responsibility.
class PatientDoctorBookingBar extends StatelessWidget {
  const PatientDoctorBookingBar({
    super.key,
    required this.dateLabel,
    required this.timeLabel,
    this.onConfirm,
    this.busy = false,
  });

  final String dateLabel, timeLabel;
  final VoidCallback? onConfirm;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PatientDesign.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final stacked =
                      bounds.maxWidth < 310 ||
                      MediaQuery.textScalerOf(context).scale(13) > 16;
                  final summary = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'JADWAL TERPILIH',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          letterSpacing: .5,
                          fontWeight: FontWeight.w700,
                          color: PatientDesign.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dateLabel.trim().isEmpty ? 'Belum dipilih' : dateLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: PatientDesign.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        timeLabel.trim().isEmpty ? 'Belum dipilih' : timeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: PatientDesign.muted,
                        ),
                      ),
                    ],
                  );
                  final action = FilledButton(
                    onPressed: busy ? null : onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: PatientDesign.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (busy) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PatientDesign.muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            busy ? 'Memproses…' : 'Konfirmasi Janji',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!busy) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ],
                    ),
                  );
                  return stacked
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 8),
                            action,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: summary),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 184),
                              child: action,
                            ),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PatientDoctorArrivalInfo extends StatelessWidget {
  const PatientDoctorArrivalInfo({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: PatientDesign.soft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: PatientDesign.border),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: PatientDesign.primary,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informasi Kedatangan Pasien',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: PatientDesign.ink,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Periksa tanggal, jam, dan ruang konsultasi yang dipilih. '
                'Siapkan tiket QR untuk check-in sesuai jadwal pelayanan.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: PatientDesign.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
