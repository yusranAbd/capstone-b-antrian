import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_brand.dart';
import 'admin_ui.dart';
import 'api.dart';
import 'config.dart';
import 'mobile_ui.dart';
import 'user_profile.dart';

/// Administrative navigation only; operational state belongs to the dashboard.
class AdminPortalHeader extends StatelessWidget implements PreferredSizeWidget {
  const AdminPortalHeader({
    super.key,
    required this.api,
    this.showBrand = true,
    this.onMenu,
    this.onProfile,
    this.onHelp,
    this.onLogout,
    this.height = 64,
  });

  final QueueApi api;
  final bool showBrand;
  final VoidCallback? onMenu, onProfile, onHelp, onLogout;
  final double height;

  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final wrapBrand =
        MediaQuery.sizeOf(context).width < 600 && scaler.scale(14) > 18;
    return math.max(
      64,
      scaler.scale(14) * 1.25 +
          scaler.scale(12) * 1.2 +
          16 +
          (wrapBrand ? scaler.scale(16) * 1.1 : 0),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const Border(bottom: BorderSide(color: AdminStyle.rule)),
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: ListenableBuilder(
          listenable: api,
          builder: (context, _) => LayoutBuilder(
            builder: (context, bounds) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final showIdentity = bounds.maxWidth >= 850 * scale;
              final showClock = bounds.maxWidth >= 560 * scale;
              final name = '${api.user?['nama'] ?? ''}'.trim();
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: bounds.maxWidth < 600 ? 8 : 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    if (onMenu != null) ...[
                      IconButton(
                        tooltip: 'Menu administrasi',
                        onPressed: onMenu,
                        icon: const Icon(Icons.menu_rounded, size: 20),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: QueueBStyle.navy,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: showBrand
                          ? const _AdminHeaderBrand()
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AdminStyle.sky,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.apartment_rounded,
                                      size: 18,
                                      color: QueueBStyle.teal,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        AppBrand.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.25,
                                          fontWeight: FontWeight.w600,
                                          color: QueueBStyle.navy,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    if (showClock) ...[
                      const SizedBox(width: 12),
                      _AdminHeaderClock(config: api.config),
                    ],
                    if (onHelp != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Bantuan administrasi',
                        onPressed: onHelp,
                        icon: const Icon(Icons.help_outline_rounded, size: 20),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: QueueBStyle.muted,
                        ),
                      ),
                    ],
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: AdminStyle.rule,
                    ),
                    _profile(context, name, showIdentity),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _profile(BuildContext context, String name, bool showIdentity) {
    final hasActions = onProfile != null || onLogout != null;
    final identity = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: AccountAvatar(api: api, radius: 17)),
            if (showIdentity) ...[
              const SizedBox(width: 9),
              SizedBox(
                width: 160,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Administrator' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: QueueBStyle.navy,
                      ),
                    ),
                    const Text(
                      'Administrator',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: QueueBStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (hasActions && showIdentity) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: QueueBStyle.muted,
              ),
            ],
          ],
        ),
      ),
    );
    final label = name.isEmpty ? 'Akun administrator' : 'Akun $name';
    if (!hasActions) return Tooltip(message: label, child: identity);
    return PopupMenuButton<_AdminAccountAction>(
      tooltip: 'Menu $label',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (action) {
        switch (action) {
          case _AdminAccountAction.profile:
            onProfile?.call();
            break;
          case _AdminAccountAction.logout:
            onLogout?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onProfile != null)
          const PopupMenuItem(
            value: _AdminAccountAction.profile,
            height: 48,
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 18),
                SizedBox(width: 10),
                Text('Profil Saya', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (onLogout != null)
          const PopupMenuItem(
            value: _AdminAccountAction.logout,
            height: 48,
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 18),
                SizedBox(width: 10),
                Text('Keluar Akun', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
      child: identity,
    );
  }
}

enum _AdminAccountAction { profile, logout }

class _AdminHeaderBrand extends StatelessWidget {
  const _AdminHeaderBrand();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DefaultTextStyle.merge(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: const QueueBBrand(compact: true, fontSize: 16, logoSize: 28),
      ),
      const Padding(
        padding: EdgeInsets.only(left: 38, top: 1),
        child: Text(
          'Portal Administrasi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, height: 1.2, color: QueueBStyle.muted),
        ),
      ),
    ],
  );
}

class _AdminHeaderClock extends StatefulWidget {
  const _AdminHeaderClock({required this.config});
  final AppConfig config;

  @override
  State<_AdminHeaderClock> createState() => _AdminHeaderClockState();
}

class _AdminHeaderClockState extends State<_AdminHeaderClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.config.now;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule_rounded, size: 16, color: QueueBStyle.muted),
        const SizedBox(width: 6),
        Text(
          '${widget.config.serviceTimeZone} · ${two(now.hour)}:${two(now.minute)}',
          style: const TextStyle(
            fontSize: 12,
            height: 1.3,
            color: QueueBStyle.muted,
          ),
        ),
      ],
    );
  }
}
