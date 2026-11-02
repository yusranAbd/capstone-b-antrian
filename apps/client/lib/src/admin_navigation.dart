import 'package:flutter/material.dart';

import 'admin_schema.dart';
import 'mobile_ui.dart';

const adminNavigationGroups = <(String, List<int>)>[
  ('Ringkasan', [-1]),
  ('Master Data', [0, 1, 2]),
  ('Jadwal & Kapasitas', [3, 4, 5]),
  ('Operasional', [6, 7]),
  ('Laporan & Aktivitas', [8, 9]),
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
  });
  final int selected;
  final ValueChanged<int>? onSelect;
  final bool collapsed;
  final VoidCallback? onToggle, onProfile;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    children: [
      Row(
        children: [
          if (!collapsed)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text(
                  'Administrasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .4,
                    color: QueueBStyle.muted,
                  ),
                ),
              ),
            ),
          if (onToggle != null)
            IconButton(
              tooltip: collapsed ? 'Perluas sidebar' : 'Ciutkan sidebar',
              onPressed: onToggle,
              icon: Icon(collapsed ? Icons.menu : Icons.menu_open),
            ),
        ],
      ),
      for (final group in adminNavigationGroups) ...[
        if (!collapsed)
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              group.$2.first == -1 ? 8 : 16,
              12,
              6,
            ),
            child: Semantics(
              header: true,
              child: Text(
                group.$1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .25,
                  color: QueueBStyle.muted,
                ),
              ),
            ),
          )
        else if (group.$2.first != -1)
          const Divider(height: 16, indent: 10, endIndent: 10),
        for (final i in group.$2)
          if (collapsed)
            IconButton(
              tooltip: adminSectionTitle(i),
              isSelected: selected == i,
              onPressed: onSelect == null ? null : () => onSelect!(i),
              icon: Icon(
                i == -1 ? Icons.dashboard_outlined : adminIcon(i),
                size: 20,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ListTile(
                minTileHeight: 44,
                dense: true,
                minLeadingWidth: 30,
                horizontalTitleGap: 10,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                selected: selected == i,
                selectedColor: Colors.white,
                selectedTileColor: QueueBStyle.darkTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected == i
                        ? QueueBStyle.darkTeal
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    i == -1 ? Icons.dashboard_outlined : adminIcon(i),
                    size: 18,
                    color: selected == i ? Colors.white : QueueBStyle.muted,
                  ),
                ),
                title: Text(
                  adminSectionTitle(i),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected == i
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: selected == i ? Colors.white : QueueBStyle.muted,
                  ),
                ),
                onTap: onSelect == null ? null : () => onSelect!(i),
              ),
            ),
      ],
      if (onProfile != null) ...[
        const Divider(height: 24),
        Tooltip(
          message: 'Profil akun',
          child: collapsed
              ? IconButton(
                  onPressed: onProfile,
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Profil Saya',
                )
              : TextButton.icon(
                  onPressed: onProfile,
                  icon: const Icon(Icons.person_outline, size: 20),
                  label: const Text('Profil Saya'),
                ),
        ),
      ],
    ],
  );
}
