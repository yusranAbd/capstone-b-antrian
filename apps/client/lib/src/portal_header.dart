import 'package:flutter/material.dart';

import 'mobile_ui.dart';
import 'queueb_palette.dart';

/// Shared header for the staff and doctor portals.
class QueueBPortalHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const QueueBPortalHeader({
    super.key,
    required this.portalTitle,
    required this.portalIcon,
    required this.roleLabel,
    required this.avatar,
    required this.name,
    required this.onProfile,
  });

  static const toolbarHeight = 60.0;

  final String portalTitle;
  final IconData portalIcon;
  final String roleLabel;
  final Widget avatar;
  final String name;
  final VoidCallback onProfile;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final enlarged = MediaQuery.textScalerOf(context).scale(14) > 20;
    final compact = width < 650 || enlarged;
    final showPortalTitle = width >= 1000 && !enlarged;

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      toolbarHeight: toolbarHeight,
      backgroundColor: QueueBPalette.console,
      foregroundColor: QueueBPalette.onConsole,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.antiAlias,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [QueueBPalette.consoleEnd, QueueBPalette.console],
          ),
        ),
      ),
      titleSpacing: 16,
      title: Row(
        children: [
          Flexible(
            child: QueueBBrand(
              compact: true,
              onDark: true,
              fontSize: compact ? 18 : 21,
              logoSize: 38,
            ),
          ),
          if (showPortalTitle) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              width: 1,
              height: 30,
              color: Colors.white38,
            ),
            Icon(portalIcon, size: 25),
            const SizedBox(width: 12),
            Text(
              portalTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
      actions: [
        if (!compact)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 1,
            height: 30,
            color: Colors.white38,
          ),
        Tooltip(
          message: 'Buka profil $name',
          child: TextButton(
            onPressed: onProfile,
            style: TextButton.styleFrom(
              foregroundColor: QueueBPalette.onConsole,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(48, 48),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                if (!compact) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: width >= 1200 ? 164 : 132,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: QueueBPalette.onConsoleMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: compact ? 6 : 12),
      ],
    );
  }
}
