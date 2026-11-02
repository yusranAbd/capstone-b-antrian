import 'dart:async';

import 'package:flutter/material.dart';

import 'config.dart';
import 'mobile_ui.dart';
import 'portal_header.dart';
import 'queueb_palette.dart';

abstract final class DoctorStyle {
  static const radius = 18.0;
  static const ink = Color(0xff101e4a);
  static const header = Color(0xff193879);
  static const primary = Color(0xff4054df);
  static const gap = 12.0;
  static const panelPadding = 12.0;
  static EdgeInsets pageInsets(BuildContext context) => EdgeInsets.all(
    MediaQuery.sizeOf(context).width < 360
        ? 12
        : MediaQuery.sizeOf(context).width < 960
        ? 16
        : 24,
  );
  static const canvas = QueueBPalette.background;
  static const paleBlue = QueueBPalette.soft;
  static const deepNavy = QueueBPalette.console;
  static const deepTeal = QueueBPalette.consoleEnd;
  static const liveMuted = QueueBPalette.onConsoleMuted;
  static const liveNumber = QueueBPalette.onConsole;
  static const rule = QueueBPalette.border;
  static const shadow = Color(0x07172544);
  static BoxDecoration get panel => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: rule),
    borderRadius: BorderRadius.circular(radius),
  );
  static final ThemeData theme = QueueBStyle.theme.copyWith(
    scaffoldBackgroundColor: canvas,
    textTheme: QueueBStyle.operationalTextTheme.copyWith(
      headlineSmall: const TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
        color: QueueBStyle.navy,
      ),
      titleLarge: const TextStyle(
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: QueueBStyle.navy,
      ),
      titleMedium: const TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: QueueBStyle.navy,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13,
        height: 1.45,
        color: QueueBStyle.navy,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: QueueBStyle.muted,
      ),
    ),
    appBarTheme: QueueBStyle.theme.appBarTheme.copyWith(
      backgroundColor: Colors.white,
      toolbarHeight: QueueBStyle.operationalToolbarHeight,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: rule)),
    ),
    inputDecorationTheme: QueueBStyle.theme.inputDecorationTheme.copyWith(
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: const TextStyle(fontSize: 13, color: QueueBStyle.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: QueueBStyle.darkTeal, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: rule),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 40),
        textStyle: const TextStyle(fontSize: 13),
      ),
    ),
  );
}

class DoctorToolbar extends StatelessWidget implements PreferredSizeWidget {
  const DoctorToolbar({
    super.key,
    required this.avatar,
    required this.name,
    required this.onProfile,
  });

  final Widget avatar;
  final String name;
  final VoidCallback onProfile;

  @override
  Size get preferredSize =>
      const Size.fromHeight(QueueBPortalHeader.toolbarHeight);

  @override
  Widget build(BuildContext context) => QueueBPortalHeader(
    portalTitle: 'Portal Dokter',
    portalIcon: Icons.medical_services_outlined,
    roleLabel: 'Dokter',
    avatar: avatar,
    name: name,
    onProfile: onProfile,
  );
}

class DoctorDashboardClock extends StatefulWidget {
  const DoctorDashboardClock({
    super.key,
    required this.config,
    required this.date,
    required this.onPickDate,
    this.loading = false,
  });
  final AppConfig config;
  final String date;
  final VoidCallback onPickDate;
  final bool loading;
  @override
  State<DoctorDashboardClock> createState() => _DoctorDashboardClockState();
}

class _DoctorDashboardClockState extends State<DoctorDashboardClock> {
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
    final day = DateTime.tryParse(widget.date);
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
    final dateLabel = day == null
        ? widget.date
        : '${days[day.weekday - 1]}, ${two(day.day)} ${months[day.month - 1]} ${day.year}';
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: widget.loading ? null : widget.onPickDate,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          icon: const Icon(
            Icons.calendar_today_outlined,
            size: 19,
            color: DoctorStyle.primary,
          ),
          label: Text(
            dateLabel,
            style: const TextStyle(fontSize: 12, color: DoctorStyle.ink),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DoctorStyle.rule),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 19,
                color: DoctorStyle.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Pukul ${two(now.hour)}.${two(now.minute)} · ${widget.config.serviceTimeZone}',
                  style: const TextStyle(fontSize: 12, color: DoctorStyle.ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DoctorStatusPill extends StatelessWidget {
  const DoctorStatusPill({
    super.key,
    required this.label,
    this.color = QueueBStyle.success,
    this.icon = Icons.circle,
  });
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: icon == Icons.circle ? 8 : 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Generic local illustration, never a photo of the signed-in person.
class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({
    super.key,
    this.size = 88,
    this.asset = 'assets/illustrations/doctor_avatar.png',
  });
  final double size;
  final String asset;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Avatar dokter generik',
    image: true,
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: DoctorStyle.paleBlue,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => Icon(
            Icons.medical_services_outlined,
            size: size * .48,
            color: QueueBStyle.darkTeal,
          ),
        ),
      ),
    ),
  );
}

class DoctorHeaderIdentity extends StatelessWidget {
  const DoctorHeaderIdentity({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DoctorAvatar(size: 36),
        if (MediaQuery.sizeOf(context).width >= 600) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: MediaQuery.sizeOf(context).width >= 1100 ? 220 : 150,
            child: Text(
              name.trim().isEmpty ? 'Dokter' : name.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    ),
  );
}

class DoctorSectionTitle extends StatelessWidget {
  const DoctorSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });
  final String title;
  final IconData icon;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      DoctorIconTile(icon: icon),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
                letterSpacing: -.15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(color: QueueBStyle.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class DoctorIconTile extends StatelessWidget {
  const DoctorIconTile({
    super.key,
    required this.icon,
    this.color = QueueBStyle.darkTeal,
    this.size = 32,
  });
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(icon, color: color, size: size * .5),
  );
}

/// Decorative clipboard drawn with native widgets; no patient data.
class DoctorQueueEmpty extends StatelessWidget {
  const DoctorQueueEmpty({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ExcludeSemantics(
          child: DoctorIconTile(icon: Icons.assignment_outlined, size: 36),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            'Belum ada antrean yang sesuai.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class DoctorInfoBlock extends StatelessWidget {
  const DoctorInfoBlock({super.key, required this.icon, required this.child});
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: DoctorStyle.paleBlue,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: QueueBStyle.darkTeal, size: 22),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    ),
  );
}
