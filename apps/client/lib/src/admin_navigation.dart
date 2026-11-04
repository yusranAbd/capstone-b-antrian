import 'package:flutter/material.dart';

import 'admin_schema.dart';
import 'mobile_ui.dart';

const adminNavigationGroups = <(String, List<int>)>[
  ('Operasional', [-1]),
  ('Master Data & Layanan', [0, 1, 2, 3]),
  ('Penjadwalan', [4, 5]),
  ('Manajemen Petugas', [6]),
  ('Sistem & Tampilan', [7, 8, 9]),
];

String adminSectionTitle(int index) => switch (index) {
  -1 => 'Dashboard',
  7 => 'Manajemen Display',
  8 => 'Laporan operasional',
  9 => 'Aktivitas sesi',
  _ => resources[index].title,
};

String adminSectionDescription(int index) => switch (index) {
  0 => 'Atur kategori, mode reservasi, dan kelengkapan layanan.',
  1 => 'Kelola profil dokter dan hubungan ke poliklinik.',
  2 => 'Tetapkan ruang pelayanan dan lokasi loket.',
  3 => 'Atur hari, jam layanan, dan kapasitas harian.',
  4 => 'Susun sesi praktik berdasarkan dokter, tanggal, dan ruang.',
  5 => 'Kelola slot konsultasi pada setiap sesi praktik.',
  6 => 'Kelola akun petugas dan penugasan ruang pelayanan.',
  _ => '',
};

IconData adminIcon(int index) => switch (index) {
  1 => Icons.medical_services_outlined,
  2 => Icons.meeting_room_outlined,
  3 => Icons.access_time,
  4 => Icons.calendar_month_outlined,
  5 => Icons.event_available,
  6 => Icons.badge_outlined,
  7 => Icons.tv_outlined,
  8 => Icons.assessment_outlined,
  9 => Icons.manage_history_outlined,
  _ => Icons.local_hospital_outlined,
};

class AdminNavigation extends StatelessWidget {
  const AdminNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
    this.collapsed = false,
    this.onToggle,
    this.onProfile,
    this.onSetup,
  });
  final int selected;
  final ValueChanged<int>? onSelect;
  final bool collapsed;
  final VoidCallback? onToggle, onProfile, onSetup;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      collapsed ? 10 : 12,
      8,
      collapsed ? 10 : 12,
      12,
    ),
    children: [
      if (!collapsed)
        DecoratedBox(
          decoration: BoxDecoration(
            color: QueueBStyle.mint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: onToggle == null ? 12 : 2,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.domain_outlined,
                  size: 18,
                  color: QueueBStyle.teal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      header: true,
                      child: const Text(
                        'ADMINISTRASI',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .5,
                          color: QueueBStyle.navy,
                        ),
                      ),
                    ),
                  ),
                ),
                if (onToggle != null)
                  IconButton(
                    tooltip: 'Ciutkan sidebar',
                    onPressed: onToggle,
                    icon: const Icon(Icons.menu_open, size: 20),
                    color: QueueBStyle.muted,
                  ),
              ],
            ),
          ),
        )
      else if (onToggle != null)
        Align(
          alignment: Alignment.center,
          child: IconButton(
            tooltip: 'Perluas sidebar',
            onPressed: onToggle,
            icon: const Icon(Icons.menu, size: 20),
            color: QueueBStyle.muted,
          ),
        ),
      for (final group in adminNavigationGroups) ...[
        if (!collapsed)
          Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              group.$2.first == -1 ? 14 : 16,
              8,
              6,
            ),
            child: Semantics(
              header: true,
              child: Text(
                group.$1.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .45,
                  color: QueueBStyle.muted,
                ),
              ),
            ),
          )
        else if (group.$2.first != -1)
          const Divider(height: 14, indent: 6, endIndent: 6),
        for (final i in group.$2) ...[
          _AdminNavigationItem(
            title: adminSectionTitle(i),
            icon: i == -1 ? Icons.dashboard_outlined : adminIcon(i),
            selected: selected == i,
            collapsed: collapsed,
            onTap: onSelect == null ? null : () => onSelect!(i),
          ),
          if (i == -1 && onSetup != null)
            _AdminNavigationItem(
              title: 'Kelola Layanan Terpadu',
              icon: Icons.layers_outlined,
              collapsed: collapsed,
              onTap: onSelect == null ? null : onSetup,
            ),
        ],
      ],
      if (onProfile != null) ...[
        const Divider(height: 24, indent: 6, endIndent: 6),
        _AdminNavigationItem(
          title: 'Profil Saya',
          icon: Icons.account_circle_outlined,
          collapsed: collapsed,
          onTap: onProfile,
        ),
      ],
    ],
  );
}

class _AdminNavigationItem extends StatelessWidget {
  const _AdminNavigationItem({
    required this.title,
    required this.icon,
    required this.collapsed,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final bool collapsed, selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Colors.white
        : onTap == null
        ? QueueBStyle.muted.withValues(alpha: .6)
        : QueueBStyle.navy;
    final item = Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: collapsed ? title : null,
      child: Material(
        color: selected ? QueueBStyle.teal : Colors.white,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          canRequestFocus: onTap != null,
          borderRadius: BorderRadius.circular(8),
          hoverColor: selected
              ? Colors.white.withValues(alpha: .1)
              : QueueBStyle.mint,
          focusColor: selected
              ? Colors.white.withValues(alpha: .2)
              : QueueBStyle.teal.withValues(alpha: .12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 12,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, size: 20, color: foreground),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: collapsed
          ? Tooltip(message: title, excludeFromSemantics: true, child: item)
          : item,
    );
  }
}
