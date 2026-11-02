import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'queueb_palette.dart';

enum QueueBFeedbackKind { error, success, info }

class _FeedbackItem {
  const _FeedbackItem(this.text, this.kind);
  final String text;
  final QueueBFeedbackKind kind;
  bool sameAs(_FeedbackItem other) => text == other.text && kind == other.kind;
}

/// Presentation only: no permission prompts, navigation or API operations.
abstract final class QueueBFeedback {
  static void show(
    BuildContext context,
    String text, {
    QueueBFeedbackKind kind = QueueBFeedbackKind.info,
  }) {
    if (text.trim().isEmpty || !context.mounted) return;
    final host = context.getInheritedWidgetOfExactType<_FeedbackScope>()?.owner;
    if (host != null) {
      host.offer(_FeedbackItem(text, kind));
      return;
    }
    // Also supports isolated screens embedded outside QueueBApp.
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        duration: Duration(seconds: kind == QueueBFeedbackKind.error ? 8 : 5),
        backgroundColor: kind == QueueBFeedbackKind.error
            ? const Color(0xffa43946)
            : kind == QueueBFeedbackKind.success
            ? const Color(0xff246b48)
            : QueueBPalette.console,
        content: Text(text),
      ),
    );
  }

  static void error(BuildContext context, String text) =>
      show(context, text, kind: QueueBFeedbackKind.error);
  static void success(BuildContext context, String text) =>
      show(context, text, kind: QueueBFeedbackKind.success);
}

/// Mount once above the router, so alerts also appear above dialogs and never
/// consume a page's layout space. Existing session and route signals own scope.
class QueueBFeedbackHost extends StatefulWidget {
  const QueueBFeedbackHost({
    super.key,
    required this.child,
    required this.session,
    required this.sessionKey,
    required this.navigation,
    required this.locationKey,
    required this.navigatorKey,
  });
  final Widget child;
  final Listenable session, navigation;
  final Object? Function() sessionKey, locationKey;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  State<QueueBFeedbackHost> createState() => _QueueBFeedbackHostState();
}

class _QueueBFeedbackHostState extends State<QueueBFeedbackHost> {
  final pending = Queue<_FeedbackItem>();
  _FeedbackItem? current, recent;
  DateTime? recentAt;
  Object? scope, location;
  Timer? timer;
  OverlayEntry? entry;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    scope = widget.sessionKey();
    location = widget.locationKey();
    widget.session.addListener(_scopeChanged);
    widget.navigation.addListener(_scopeChanged);
  }

  @override
  void didUpdateWidget(covariant QueueBFeedbackHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_scopeChanged);
      widget.session.addListener(_scopeChanged);
    }
    if (oldWidget.navigation != widget.navigation) {
      oldWidget.navigation.removeListener(_scopeChanged);
      widget.navigation.addListener(_scopeChanged);
    }
    if (oldWidget.navigatorKey != widget.navigatorKey ||
        oldWidget.session != widget.session) {
      _clear();
    }
    _scopeChanged();
  }

  void _scopeChanged() {
    final nextScope = widget.sessionKey(), nextLocation = widget.locationKey();
    if (scope == nextScope && location == nextLocation) return;
    scope = nextScope;
    location = nextLocation;
    _clear();
  }

  void _removeEntry() {
    final old = entry;
    entry = null;
    if (old == null) return;
    old.remove();
    old.dispose();
  }

  void _clear() {
    timer?.cancel();
    pending.clear();
    current = null;
    recent = null;
    recentAt = null;
    _removeEntry();
  }

  void offer(_FeedbackItem item) {
    if (!mounted) return;
    _scopeChanged();
    if (current?.sameAs(item) == true || pending.any((p) => p.sameAs(item))) {
      return;
    }
    if (recent?.sameAs(item) == true &&
        recentAt != null &&
        DateTime.now().difference(recentAt!) < const Duration(seconds: 2)) {
      return;
    }
    if (current != null) {
      if (pending.length >= 4) pending.removeFirst();
      pending.add(item);
      return;
    }
    _present(item);
  }

  void _present(_FeedbackItem item) {
    timer?.cancel();
    current = item;
    recent = item;
    recentAt = DateTime.now();
    revision++;
    _render();
    if (!MediaQuery.accessibleNavigationOf(context)) {
      timer = Timer(
        Duration(seconds: item.kind == QueueBFeedbackKind.error ? 8 : 5),
        dismiss,
      );
    }
  }

  void _render() {
    if (!mounted || current == null) return;
    if (entry != null) {
      entry!.markNeedsBuild();
      return;
    }
    final overlay = widget.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            current != null &&
            widget.navigatorKey.currentState?.overlay != null) {
          _render();
        }
      });
      return;
    }
    entry = OverlayEntry(builder: _buildPopup);
    overlay.insert(entry!);
  }

  Widget _buildPopup(BuildContext context) {
    if (current == null) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: MediaQuery.sizeOf(context).width >= 700
                ? Alignment.topRight
                : Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _FeedbackCard(
                key: ValueKey(revision),
                item: current!,
                onClose: dismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void dismiss() {
    timer?.cancel();
    if (!mounted) return;
    if (pending.isNotEmpty) {
      _present(pending.removeFirst());
    } else {
      current = null;
      _removeEntry();
    }
  }

  @override
  void dispose() {
    _clear();
    widget.session.removeListener(_scopeChanged);
    widget.navigation.removeListener(_scopeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _FeedbackScope(owner: this, child: widget.child);
}

class _FeedbackScope extends InheritedWidget {
  const _FeedbackScope({required this.owner, required super.child});
  final _QueueBFeedbackHostState owner;
  @override
  bool updateShouldNotify(_FeedbackScope oldWidget) => oldWidget.owner != owner;
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({super.key, required this.item, required this.onClose});
  final _FeedbackItem item;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = switch (item.kind) {
      QueueBFeedbackKind.error => (
        const Color(0xffa43946),
        Icons.error_outline_rounded,
        'Terjadi kesalahan',
      ),
      QueueBFeedbackKind.success => (
        const Color(0xff246b48),
        Icons.check_circle_outline_rounded,
        'Berhasil',
      ),
      QueueBFeedbackKind.info => (
        QueueBPalette.primary,
        Icons.info_outline_rounded,
        'Informasi',
      ),
    };
    final maxHeight = math.max(
      80.0,
      math.min(320.0, MediaQuery.sizeOf(context).height * .45),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. ${item.text}',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
        child: Material(
          elevation: 8,
          shadowColor: const Color(0x29172544),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withValues(alpha: .28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 23),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: color,
                                fontSize: 14,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          ExcludeSemantics(
                            child: SelectableText(
                              item.text,
                              style: const TextStyle(
                                color: QueueBPalette.ink,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup pemberitahuan',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 19),
                    style: IconButton.styleFrom(
                      foregroundColor: QueueBPalette.muted,
                      minimumSize: const Size(44, 44),
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
}

/// Observe a mounted feedback value once, without creating build-time effects.
class QueueBPopupNotice extends StatefulWidget {
  const QueueBPopupNotice(
    this.text, {
    super.key,
    this.kind = QueueBFeedbackKind.info,
  });
  final String text;
  final QueueBFeedbackKind kind;
  @override
  State<QueueBPopupNotice> createState() => _QueueBPopupNoticeState();
}

class _QueueBPopupNoticeState extends State<QueueBPopupNotice> {
  (String, QueueBFeedbackKind)? seen;
  int revision = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant QueueBPopupNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    final value = (widget.text, widget.kind);
    if (seen == value) return;
    seen = value;
    final request = ++revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          request != revision ||
          !TickerMode.valuesOf(context).enabled ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      QueueBFeedback.show(context, widget.text, kind: widget.kind);
    });
  }

  @override
  void dispose() {
    revision++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
