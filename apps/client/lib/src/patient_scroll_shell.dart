import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'patient_scroll_input.dart';
import 'queueb_motion.dart';

/// Patient-only chrome. Content stays mounted while the bars release space.
/// No timers or scroll controllers are attached to the individual pages.
class PatientScrollShell extends StatefulWidget {
  const PatientScrollShell({
    super.key,
    required this.pageKey,
    required this.body,
    required this.bottomNavigationBar,
    this.header,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.acceptNestedScrolls = false,
    this.keepBottomNavigationVisible = false,
    this.nestedScrollKey,
    this.activeNestedScrollKey,
  });

  final Object pageKey;
  final Widget body, bottomNavigationBar;
  final PreferredSizeWidget? header;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool acceptNestedScrolls;

  /// A booking confirmation remains reachable independently of scroll chrome.
  final bool keepBottomNavigationVisible;
  final GlobalKey<NestedScrollViewState>? nestedScrollKey;
  final Key? activeNestedScrollKey;

  @override
  State<PatientScrollShell> createState() => _PatientScrollShellState();
}

class _PatientScrollShellState extends State<PatientScrollShell>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: 1,
    duration: QueueBMotion.component,
    reverseDuration: QueueBMotion.component,
  );
  late final _visibility = CurvedAnimation(
    parent: _controller,
    curve: QueueBMotion.position,
    reverseCurve: QueueBMotion.position,
  );
  final _scrollingContexts = <BuildContext>{};
  double _travel = 0;
  BuildContext? _scrollContext;
  bool _targetVisible = true;
  final _inputClock = Stopwatch();
  Duration? _lastInput;
  double _inputDirection = 0;
  late final void Function() _stopInput;

  @override
  void initState() {
    super.initState();
    _inputClock.start();
    FocusManager.instance.addListener(_onFocusChanged);
    _stopInput = observePatientScrollInput((direction) {
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent == false ||
          _keepControlsVisible ||
          _editing) {
        return;
      }
      if (_lastInput == null ||
          _inputClock.elapsed - _lastInput! >
              const Duration(milliseconds: 450)) {
        _travel = 0;
      }
      _lastInput = _inputClock.elapsed;
      _inputDirection = direction;
    });
  }

  // main.dart always enables Web semantics; that flag alone does not identify
  // a screen reader there. Native platforms retain their accessibility policy.
  bool get _keepControlsVisible =>
      !kIsWeb && MediaQuery.accessibleNavigationOf(context);

  bool get _editing {
    final focused = FocusManager.instance.primaryFocus?.context;
    return MediaQuery.viewInsetsOf(context).bottom > 0 ||
        focused?.widget is EditableText ||
        focused?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _onFocusChanged() {
    if (!mounted || !_editing) return;
    _scrollingContexts.clear();
    _travel = 0;
    _show(true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A screen reader enabled mid-session must never inherit hidden controls.
    if (_keepControlsVisible || _editing) {
      _targetVisible = true;
      _controller.value = 1;
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _targetVisible ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant PatientScrollShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _scrollingContexts.clear();
      _travel = 0;
      _scrollContext = null;
      _lastInput = null;
      _show(true);
    }
  }

  void _show(bool visible) {
    final target = visible ? 1.0 : 0.0;
    if (_targetVisible == visible &&
        (_controller.value == target || _controller.isAnimating)) {
      return;
    }
    _targetVisible = visible;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = target;
    } else if (visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  bool _onScroll(ScrollNotification notification) {
    // Ignore horizontal strips, programmatic ensureVisible/jumpTo and dialogs.
    // Home opts into vertical notifications from its nested tab lists only.
    // Web semantics maps DOM scrolling to jumpTo; trusted input must precede it.
    if (notification.metrics.axis != Axis.vertical ||
        !_relevant(notification.context, notification.depth)) {
      return false;
    }
    if (notification is UserScrollNotification) {
      final source = notification.context;
      if (notification.direction == ScrollDirection.idle) {
        _scrollingContexts.remove(source);
        if (_scrollingContexts.isEmpty) _travel = 0;
      }
    }
    if (_keepControlsVisible ||
        _editing ||
        ModalRoute.of(context)?.isCurrent == false) {
      _scrollingContexts.clear();
      _travel = 0;
      if (_editing || _keepControlsVisible) _show(true);
      return false;
    }
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle &&
        notification.context != null) {
      _scrollingContexts.add(notification.context!);
    }
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      // Restoring the top always restores navigation, including a clamped offset.
      // Only hiding requires evidence of user input.
      if (_atTop(notification.metrics)) {
        _travel = 0;
        _show(true);
        return false;
      }
      final webInput =
          kIsWeb &&
          _lastInput != null &&
          _inputClock.elapsed - _lastInput! <
              const Duration(milliseconds: 450) &&
          delta.sign == _inputDirection;
      if (!_scrollingContexts.contains(notification.context) &&
          notification.dragDetails == null &&
          !webInput) {
        return false;
      }
      if (delta != 0) _scrollContext = notification.context;
      if (!_pageFits(notification.metrics) && delta != 0) {
        if (_travel.sign != delta.sign) _travel = 0;
        _travel += delta;
        if (_travel.abs() >= QueueBMotion.scrollThreshold) _show(_travel < 0);
      }
    }
    return false;
  }

  /// Home's outer header and selected tab are a single vertical page.
  /// An inner list at zero does not mean the shared header is at the top.
  List<ScrollPosition> get _nestedPositions {
    final nested = widget.nestedScrollKey?.currentState;
    if (!widget.acceptNestedScrolls || nested == null) return const [];
    return [
          ...nested.outerController.positions,
          ...nested.innerController.positions.where(
            (position) =>
                position.context.storageContext
                    .findAncestorWidgetOfExactType<CustomScrollView>()
                    ?.key ==
                widget.activeNestedScrollKey,
          ),
        ]
        .where(
          (position) => position.hasPixels && position.hasContentDimensions,
        )
        .toList();
  }

  bool _atTop(ScrollMetrics metrics) {
    final positions = _nestedPositions;
    return positions.isEmpty
        ? metrics.pixels <= metrics.minScrollExtent
        : positions.every((p) => p.pixels <= p.minScrollExtent + .5);
  }

  bool _pageFits(ScrollMetrics metrics) {
    final positions = _nestedPositions;
    return positions.isEmpty
        ? metrics.maxScrollExtent <= metrics.minScrollExtent
        : positions.every((p) => p.maxScrollExtent <= p.minScrollExtent + .5);
  }

  bool _relevant(BuildContext? context, int depth) {
    if (depth == 0) {
      final nested = widget.nestedScrollKey?.currentState;
      if (widget.acceptNestedScrolls && nested != null) {
        return context?.findAncestorStateOfType<NestedScrollViewState>() ==
            nested;
      }
      return true;
    }
    if (!widget.acceptNestedScrolls || context == null) return false;
    ScrollView? nearest;
    context.visitAncestorElements((element) {
      if (element.widget is ScrollView) {
        nearest = element.widget as ScrollView;
        return false;
      }
      return true;
    });
    if (widget.activeNestedScrollKey != null) {
      return nearest?.key == widget.activeNestedScrollKey;
    }
    return const [
      // Legacy V6 and the V9 native TabBarView scroll keys.
      PageStorageKey('home-walk-in-list'),
      PageStorageKey('home-appointment-list'),
      PageStorageKey('patient-home-walk-in-scroll'),
      PageStorageKey('patient-home-appointments-scroll'),
    ].contains(nearest?.key);
  }

  Widget _bar(Widget child, {required bool bottom}) => Focus(
    onFocusChange: (focused) {
      if (focused) _show(true);
    },
    child: IgnorePointer(
      ignoring: _controller.value == 0,
      child: ExcludeFocus(
        excluding: _controller.value == 0,
        child: ExcludeSemantics(
          excluding: _controller.value == 0,
          child: SizeTransition(
            key: ValueKey(
              bottom ? 'patient-chrome-bottom' : 'patient-chrome-top',
            ),
            sizeFactor: _visibility,
            alignment: bottom ? Alignment.bottomCenter : Alignment.topCenter,
            child: ClipRect(
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, bottom ? 1 : -1),
                  end: Offset.zero,
                ).animate(_visibility),
                child: FadeTransition(opacity: _visibility, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Tampilkan navigasi pasien'): () =>
            _show(true),
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
          // Collapsing bars can make a short page fit or clamp its offset to
          // zero. Restore controls even when no reverse scroll is possible.
          if (identical(notification.context, _scrollContext) &&
              _relevant(notification.context, notification.depth) &&
              metrics.axis == Axis.vertical &&
              (_pageFits(metrics) || _atTop(metrics)) &&
              _controller.value < 1 &&
              _controller.status != AnimationStatus.forward) {
            _show(true);
          }
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.body,
        ),
      ),
    ),
    builder: (context, body) => Scaffold(
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: widget.keepBottomNavigationVisible
          ? widget.bottomNavigationBar
          : _bar(widget.bottomNavigationBar, bottom: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.header != null)
              _bar(
                SizedBox(
                  height: widget.header!.preferredSize.height,
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: widget.header!,
                  ),
                ),
                bottom: false,
              ),
            Expanded(child: body!),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _scrollingContexts.clear();
    _visibility.dispose();
    _stopInput();
    _inputClock.stop();
    _controller.dispose();
    super.dispose();
  }
}
