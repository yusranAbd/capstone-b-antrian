import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'config.dart';
import 'mobile_ui.dart';
import 'patient_design.dart';
import 'doctor_professional.dart';
import 'queueb_motion.dart';

// Tokens remain in QueueBStyle; no changes to shared themes or other roles.
String patientDate(String value) {
  final day = DateTime.tryParse(dateOnly(value));
  if (day == null) return '—';
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
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  return '${days[day.weekday - 1]}, ${day.day} ${months[day.month - 1]} ${day.year}';
}

String patientCompactDate(String value) {
  final date = DateTime.tryParse(dateOnly(value));
  if (date == null) return 'Tanggal belum tersedia';
  const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
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
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

String patientTime(Json value, AppConfig config) =>
    '${clockOnly(config.localInput(value['mulaiPada']))} – ${clockOnly(config.localInput(value['selesaiPada']))}';

IconData clinicIcon(String name) {
  final text = name.toLowerCase();
  if (text.contains('mata')) return Icons.visibility_outlined;
  if (text.contains('anak')) return Icons.child_care_outlined;
  if (text.contains('gigi')) return Icons.health_and_safety_outlined;
  if (text.contains('jantung')) return Icons.monitor_heart_outlined;
  if (text.contains('tht')) return Icons.hearing_outlined;
  if (text.contains('saraf')) return Icons.psychology_outlined;
  if (text.contains('kandungan')) return Icons.pregnant_woman_outlined;
  if (text.contains('bedah')) return Icons.healing_outlined;
  if (text.contains('rehabilitasi')) return Icons.accessibility_new;
  if (text.contains('kulit')) return Icons.back_hand_outlined;
  if (text.contains('urologi')) return Icons.water_drop_outlined;
  return Icons.medical_services_outlined;
}

/// Compact patient-only navigation; no changes to shared role themes.
class PatientBottomNavigation extends StatelessWidget {
  static const activeColor = Color(0xff0968d8);
  const PatientBottomNavigation({
    super.key,
    required this.selectedIndex,
    this.onSelected,
    this.maxWidth = 680,
  });
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: PatientDesign.paper,
          border: Border(top: BorderSide(color: PatientDesign.border)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarTheme.of(context).copyWith(
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  size: 23,
                  color: states.contains(WidgetState.selected)
                      ? activeColor
                      : PatientDesign.muted,
                ),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 12,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: states.contains(WidgetState.selected)
                      ? activeColor
                      : PatientDesign.muted,
                ),
              ),
            ),
            child: NavigationBar(
              height: (MediaQuery.textScalerOf(context).scale(12) * 1.2 + 52)
                  .clamp(68, double.infinity),
              animationDuration: QueueBMotion.duration(
                context,
                QueueBMotion.component,
              ),
              backgroundColor: PatientDesign.paper,
              indicatorColor: Colors.transparent,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_outlined),
                  label: 'Beranda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_available_outlined),
                  selectedIcon: Icon(Icons.event_available_outlined),
                  label: 'Reservasi',
                ),
                NavigationDestination(
                  icon: Icon(Icons.info_outline_rounded),
                  label: 'Informasi',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_outline),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Only animate the incoming *retained* branch. Do not key or replace the
/// StatefulNavigationShell: doing so would discard tab state, scroll offsets,
/// navigator stacks and existing BLoC owners. Root branch changes animate here;
/// detail/booking routes retain their existing GoRouter transition instead.
class PatientBranchReveal extends StatefulWidget {
  const PatientBranchReveal({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<PatientBranchReveal> createState() => _PatientBranchRevealState();
}

class _PatientBranchRevealState extends State<PatientBranchReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: QueueBMotion.component,
    value: 1,
  );
  late final Animation<double> _fade = Tween<double>(
    begin: QueueBMotion.minimumOpacity,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: QueueBMotion.entering));
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, .028),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: QueueBMotion.entering));
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (widget.active && !QueueBMotion.reduced(context)) {
        _controller.forward(from: 0);
      }
    } else if (QueueBMotion.reduced(context)) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant PatientBranchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (QueueBMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    } else if (!widget.active) {
      _controller.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Native TabBar and TabBarView share one motion clock and honor Reduce Motion.
/// There is no extra AnimatedSwitcher around the retained tab scroll views.
class _PatientNativeMotionTabController extends TabController {
  _PatientNativeMotionTabController({
    required super.initialIndex,
    required super.vsync,
    required this.reduced,
  }) : super(length: 2, animationDuration: QueueBMotion.component);

  final bool Function() reduced;

  @override
  Duration get animationDuration =>
      reduced() ? QueueBMotion.instant : QueueBMotion.component;

  @override
  void animateTo(int value, {Duration? duration, Curve curve = Curves.ease}) {
    super.animateTo(
      value,
      duration: reduced()
          ? QueueBMotion.instant
          : duration ?? QueueBMotion.component,
      curve: curve == Curves.ease ? QueueBMotion.position : curve,
    );
  }
}

/// Flutter-native, two-tab home navigation. The parent retains ownership of
/// the selected mode, queues, sessions, search and HTTP/socket subscriptions.
/// This widget owns only the local TabController and scroll positions.
class PatientNativeHomeTabs extends StatefulWidget {
  const PatientNativeHomeTabs({
    super.key,
    required this.walkInSelected,
    required this.onChanged,
    required this.headerSlivers,
    required this.walkInSlivers,
    required this.appointmentSlivers,
    this.tabsFirst = false,
    this.nestedScrollKey,
  });

  final bool walkInSelected;
  final bool tabsFirst;
  final GlobalKey<NestedScrollViewState>? nestedScrollKey;
  final ValueChanged<bool>? onChanged;
  final List<Widget> headerSlivers;
  final List<Widget> walkInSlivers;
  final List<Widget> appointmentSlivers;

  @override
  State<PatientNativeHomeTabs> createState() => _PatientNativeHomeTabsState();
}

class _PatientNativeHomeTabsState extends State<PatientNativeHomeTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.walkInSelected ? 0 : 1;
    _controller = _PatientNativeMotionTabController(
      initialIndex: _lastIndex,
      vsync: this,
      reduced: () => QueueBMotion.reduced(context),
    )..addListener(_notifyTabChanged);
  }

  void _notifyTabChanged() {
    if (_controller.index == _lastIndex) return;
    _lastIndex = _controller.index;
    widget.onChanged?.call(_lastIndex == 0);
  }

  @override
  void didUpdateWidget(covariant PatientNativeHomeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final expectedIndex = widget.walkInSelected ? 0 : 1;
    if (_controller.index != expectedIndex) {
      _lastIndex = expectedIndex;
      _controller.animateTo(expectedIndex);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_notifyTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final enabled = widget.onChanged != null;
      final scaler = MediaQuery.textScalerOf(context);
      final verticalLabel = scaler.scale(13) > 21;
      final labelStyle =
          Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600) ??
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
      // Measure the labels instead of limiting text scaling or assuming that
      // every language/font setting fits a single fixed-height tab.
      final tabWidth = ((bounds.maxWidth - 32) / 2 - 16)
          .clamp(1.0, double.infinity)
          .toDouble();
      final labelWidth = (tabWidth - (verticalLabel ? 0 : 27))
          .clamp(1.0, double.infinity)
          .toDouble();
      double labelHeight = 0;
      for (final label in const ['Ambil Antrean', 'Janji Temu']) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: labelWidth);
        if (painter.height > labelHeight) labelHeight = painter.height;
        painter.dispose();
      }
      final tabHeight = (labelHeight + (verticalLabel ? 26 : 0) + 20)
          .clamp(48.0, double.infinity)
          .toDouble();
      Widget tab(String label, IconData icon, String key) {
        final title = Text(label, textAlign: TextAlign.center);
        return Tab(
          key: ValueKey(key),
          height: tabHeight,
          child: verticalLabel
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(height: 8),
                    title,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                    Flexible(child: title),
                  ],
                ),
        );
      }

      final tabsSurface = Material(
        color: PatientDesign.background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: PatientDesign.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: AbsorbPointer(
              absorbing: !enabled,
              child: ExcludeFocus(
                excluding: !enabled,
                child: TabBar(
                  controller: _controller,
                  labelColor: PatientDesign.primary,
                  unselectedLabelColor: PatientDesign.muted,
                  dividerColor: Colors.transparent,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(
                      color: PatientDesign.primary,
                      width: 2,
                    ),
                    insets: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  labelStyle: labelStyle,
                  unselectedLabelStyle: labelStyle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    tab(
                      'Ambil Antrean',
                      Icons.confirmation_number_outlined,
                      'home-mode-walkIn',
                    ),
                    tab(
                      'Janji Temu',
                      Icons.calendar_month_outlined,
                      'home-mode-appointment',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final scrollView = NestedScrollView(
        key: widget.nestedScrollKey,
        // Search and visit keep a single shared owner. In tabs-first mode the
        // fixed tab surface sits outside this coordinated scrolling viewport.
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          ...widget.headerSlivers,
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: widget.tabsFirst
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverPersistentHeader(
                    pinned: true,
                    delegate: _PatientNativeTabHeader(
                      height: tabHeight + 16,
                      child: tabsSurface,
                    ),
                  ),
          ),
        ],
        body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              ...ScrollConfiguration.of(context).dragDevices,
              PointerDeviceKind.mouse,
            },
          ),
          child: TabBarView(
            key: const ValueKey('patient-home-tab-pages'),
            controller: _controller,
            physics: enabled
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            children: [
              _PatientNativeTabBody(
                key: const PageStorageKey('patient-home-walk-in'),
                scrollKey: const PageStorageKey('patient-home-walk-in-scroll'),
                slivers: widget.walkInSlivers,
              ),
              _PatientNativeTabBody(
                key: const PageStorageKey('patient-home-appointments'),
                scrollKey: const PageStorageKey(
                  'patient-home-appointments-scroll',
                ),
                slivers: widget.appointmentSlivers,
              ),
            ],
          ),
        ),
      );
      return widget.tabsFirst
          ? Column(
              children: [
                SizedBox(height: tabHeight + 16, child: tabsSurface),
                Expanded(child: scrollView),
              ],
            )
          : scrollView;
    },
  );
}

class _PatientNativeTabBody extends StatelessWidget {
  const _PatientNativeTabBody({
    super.key,
    required this.slivers,
    required this.scrollKey,
  });
  final List<Widget> slivers;
  final PageStorageKey<String> scrollKey;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: scrollKey,
    slivers: [
      SliverOverlapInjector(
        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      ),
      ...slivers,
    ],
  );
}

class _PatientNativeTabHeader extends SliverPersistentHeaderDelegate {
  const _PatientNativeTabHeader({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(covariant _PatientNativeTabHeader oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}

class PatientHeading extends StatelessWidget {
  const PatientHeading({
    super.key,
    required this.title,
    this.onBack,
    this.caption,
  });
  final String title;
  final String? caption;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: 'Kembali',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: PatientDesign.navy,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: const TextStyle(
                    color: PatientDesign.muted,
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

class PatientDoctorCard extends StatelessWidget {
  const PatientDoctorCard({
    super.key,
    required this.doctor,
    required this.config,
    required this.schedule,
    required this.onDetails,
  });
  final Json doctor;
  final AppConfig config;
  final String schedule;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfessionalDoctorAvatar(
              config: config,
              photo: doctor['fotoProfil'],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label(doctor),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PatientDesign.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${doctor['spesialisasi'] ?? 'Spesialisasi belum dicantumkan'}',
                    style: const TextStyle(
                      color: PatientDesign.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          rows(doctor['dokterLayanan'])
              .where((link) => link['aktif'] != false)
              .map((link) => label(object(link['layanan'])))
              .join(', '),
          style: const TextStyle(color: PatientDesign.muted, fontSize: 12),
        ),
        Text(
          schedule,
          style: const TextStyle(color: PatientDesign.darkTeal, fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onDetails,
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Lihat Detail Dokter'),
        ),
      ],
    ),
  );
}

class PatientInfoRow extends StatelessWidget {
  const PatientInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: PatientDesign.mint,
          foregroundColor: PatientDesign.darkTeal,
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: PatientDesign.muted,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: PatientDesign.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AppointmentReview extends StatelessWidget {
  const AppointmentReview({
    super.key,
    required this.doctor,
    required this.clinic,
    required this.session,
    required this.slot,
    required this.config,
  });
  final Json doctor, clinic, session, slot;
  final AppConfig config;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PatientHeading(title: 'Konfirmasi Janji Temu'),
            PatientInfoRow(
              icon: Icons.person_outline,
              title: 'Dokter',
              value: label(doctor),
            ),
            PatientInfoRow(
              icon: Icons.local_hospital_outlined,
              title: 'Poliklinik',
              value: label(clinic),
            ),
            PatientInfoRow(
              icon: Icons.room_outlined,
              title: 'Ruang / Loket',
              value:
                  '${object(session['loket'])['kode'] ?? ''} · ${label(object(session['loket']))}',
            ),
            PatientInfoRow(
              icon: Icons.calendar_month_outlined,
              title: 'Tanggal',
              value: patientDate('${session['tanggal']}'),
            ),
            PatientInfoRow(
              icon: Icons.schedule,
              title: 'Waktu',
              value: '${patientTime(slot, config)} · ${config.serviceTimeZone}',
            ),
            const SizedBox(height: 12),
            const MobileNotice(
              'Nomor tiket diterbitkan setelah booking berhasil. Ketersediaan diperiksa kembali oleh server.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Konfirmasi Janji Temu'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    ),
  );
}
