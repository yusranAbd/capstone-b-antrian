import 'package:flutter/material.dart';

import 'mobile_ui.dart';

// Operational QueueB / shared blue palette / compact service console.
// Scoped to PETUGAS; see docs/frontend/QUEUEB_UI_UX_GUIDELINES.md.
abstract final class StaffStyle {
  static const radius = 16.0;
  static const ink = Color(0xff101e4a);
  static const header = Color(0xff203874);
  static const blue = Color(0xff4054df);
  static const soft = Color(0xffeef1ff);
  static final ThemeData theme = _buildTheme();
  static ThemeData _buildTheme() {
    final base = QueueBStyle.theme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return base.copyWith(
      textTheme: QueueBStyle.operationalTextTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 14,
          height: 1.45,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.45,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.4,
          color: QueueBStyle.muted,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 12),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        toolbarHeight: QueueBStyle.operationalToolbarHeight,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: QueueBStyle.border)),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(fontSize: 13, color: QueueBStyle.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QueueBStyle.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QueueBStyle.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QueueBStyle.darkTeal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: shape,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: shape,
          side: const BorderSide(color: QueueBStyle.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          iconSize: 20,
        ),
      ),
    );
  }
}

class StaffMetricCard extends StatelessWidget {
  const StaffMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.surface,
    required this.accent,
    required this.description,
    this.compact = false,
  });
  final String label, value, description;
  final IconData icon;
  final Color surface, accent;
  final bool compact;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: description,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .10)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, size: compact ? 24 : 28, color: accent),
          ),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: StaffStyle.ink,
                    fontSize: compact ? 27 : 32,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: compact ? 12 : 14, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class StaffStatusPill extends StatelessWidget {
  const StaffStatusPill(this.status, {super.key});
  final Object? status;

  @override
  Widget build(BuildContext context) {
    final (text, icon, ink, surface) = switch (status) {
      'MENUNGGU' => (
        'Menunggu',
        Icons.schedule_rounded,
        const Color(0xff995500),
        const Color(0xfffff3df),
      ),
      'DIPANGGIL' => (
        'Dipanggil',
        Icons.campaign_outlined,
        const Color(0xff274dab),
        const Color(0xffe7efff),
      ),
      'DILAYANI' => (
        'Sedang dilayani',
        Icons.circle,
        const Color(0xff145e37),
        const Color(0xffe0f6e9),
      ),
      'SELESAI' => (
        'Selesai',
        Icons.check_circle_outline_rounded,
        const Color(0xff145e37),
        const Color(0xffe0f6e9),
      ),
      'CHECK_IN' => (
        'Check-in',
        Icons.login_rounded,
        const Color(0xff245c86),
        const Color(0xffe5f2ff),
      ),
      'DILEWATI' => (
        'Dilewati',
        Icons.pause_circle_outline_rounded,
        QueueBStyle.muted,
        const Color(0xffedf1f7),
      ),
      _ => ('Siap melayani', Icons.circle, QueueBStyle.muted, StaffStyle.soft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 9 : 15, color: ink),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StaffPanel extends StatelessWidget {
  const StaffPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.action,
    this.dark = false,
    this.expand = false,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;
  final bool dark, expand;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: Material(
      color: dark ? QueueBStyle.console : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: dark ? QueueBStyle.console : QueueBStyle.border,
        ),
        borderRadius: BorderRadius.circular(StaffStyle.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: .08)
                        : QueueBStyle.mint,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: dark ? Colors.white : QueueBStyle.darkTeal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.15,
                      color: dark ? Colors.white : QueueBStyle.navy,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            if (expand) Expanded(child: child) else child,
          ],
        ),
      ),
    ),
  );
}

class StaffEmpty extends StatelessWidget {
  const StaffEmpty(this.text, {super.key, this.dark = false});
  final String text;
  final bool dark;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 24,
          color: dark ? QueueBStyle.mint : QueueBStyle.muted,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: dark ? Colors.white : QueueBStyle.muted,
            ),
          ),
        ),
      ],
    ),
  );
}
