import 'package:flutter/material.dart';

import 'config.dart';
import 'features/admin/data/admin_catalog_repository.dart';

/// Uses server evidence, never infers operational readiness from a row count.
class AdminServiceReadiness extends StatelessWidget {
  const AdminServiceReadiness({
    super.key,
    required this.catalog,
    required this.serviceId,
    required this.today,
  });
  final Map<String, List<Json>> catalog;
  final Object? serviceId;
  final String today;

  @override
  Widget build(BuildContext context) {
    final report = (catalog[adminReadinessPath] ?? const <Json>[])
        .where(
          (r) => r['layananId'] == serviceId && r['tanggalPenilaian'] == today,
        )
        .firstOrNull;
    final issues = report?['kekurangan'];
    final known = report != null && issues is List && report['lengkap'] is bool;
    final complete = known && report['lengkap'] == true && issues.isEmpty;
    final label = !known
        ? 'Belum diperiksa'
        : complete
        ? 'Lengkap'
        : 'Belum lengkap';
    return TextButton.icon(
      icon: Icon(
        complete ? Icons.check_circle_outline : Icons.info_outline,
        size: 17,
      ),
      label: Text(label),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kelengkapan konfigurasi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Penilaian mencakup konfigurasi layanan, penugasan petugas hari ini, serta sesi dan slot yang belum berakhir untuk layanan janji temu. Ketersediaan reservasi tetap mengikuti jam, kapasitas, dan aturan pelayanan.',
                ),
                const SizedBox(height: 12),
                if (!known)
                  const Text(
                    'Hasil pemeriksaan belum tersedia. Muat ulang katalog untuk memeriksa konfigurasi.',
                  )
                else if (complete)
                  const Text(
                    'Persyaratan konfigurasi sudah lengkap pada saat pemeriksaan.',
                  )
                else
                  for (final issue in issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $issue'),
                    ),
                if (known) Text('Diperiksa: ${report['diperolehPada']}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }
}
