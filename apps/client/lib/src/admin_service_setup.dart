import 'package:flutter/material.dart';

import 'config.dart';
import 'queueb_feedback.dart';
import 'admin_service_readiness.dart';
import 'service_category.dart';
import 'features/admin/data/admin_catalog_repository.dart';

/// A single place to complete existing ADMIN configuration operations.
/// Each action still uses the existing API/Cubit and confirms a separate save.
/// This view never batches POST requests or treats a partial setup as atomic.
enum AdminSetupAction {
  createService,
  editService,
  addRoom,
  addHours,
  createDoctor,
  linkDoctor,
  addPractice,
  addSlot,
}

typedef AdminSetupHandler = Future<void> Function(
  AdminSetupAction action,
  String? serviceId,
  String? relatedId,
);

class AdminServiceSetup extends StatefulWidget {
  const AdminServiceSetup({
    super.key,
    required this.repository,
    required this.onAction,
  });

  final AdminCatalogRepository repository;
  final AdminSetupHandler onAction;

  @override
  State<AdminServiceSetup> createState() => _AdminServiceSetupState();
}

class _AdminServiceSetupState extends State<AdminServiceSetup> {
  int step = 0;
  bool busy = false;
  String? selectedId;
  String? error;

  Map<String, List<Json>> get catalog => widget.repository.snapshot.collections;
  List<Json> get services => catalog['/layanan'] ?? const [];
  Json? get selected =>
      services.where((r) => r['id'] == selectedId).firstOrNull;
  List<Json> get rooms => (catalog['/loket'] ?? const [])
      .where((r) => r['layananId'] == selectedId)
      .toList();
  List<Json> get hours => (catalog['/jadwal-layanan'] ?? const [])
      .where((r) => r['layananId'] == selectedId)
      .toList();
  List<Json> get linkedDoctors => (catalog['/dokter'] ?? const [])
      .where(
        (d) =>
            d['aktif'] == true &&
            rows(d['dokterLayanan'])
                .any((l) => l['layananId'] == selectedId && l['aktif'] == true),
      )
      .toList();
  List<Json> get otherDoctors => (catalog['/dokter'] ?? const [])
      .where(
        (d) =>
            d['aktif'] == true &&
            !rows(d['dokterLayanan'])
                .any((l) => l['layananId'] == selectedId && l['aktif'] == true),
      )
      .toList();
  List<Json> get practices => (catalog['/jadwal-praktik'] ?? const [])
      .where(
        (p) =>
            object(p['dokterLayanan'])['layananId'] == selectedId ||
            object(object(p['dokterLayanan'])['layanan'])['id'] == selectedId,
      )
      .toList();

  Future<void> perform(AdminSetupAction action, {String? relatedId}) async {
    if (busy || !widget.repository.active) return;
    final before = services.map((r) => '${r['id']}').toSet();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onAction(action, selectedId, relatedId);
      if (!mounted) return;
      if (action == AdminSetupAction.createService) {
        final created = services
            .where((r) => !before.contains('${r['id']}'))
            .toList();
        if (created.length == 1) selectedId = '${created.first['id']}';
      }
    } catch (e) {
      if (mounted) error = 'Operasi belum selesai: $e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget action(
    String title,
    IconData icon,
    AdminSetupAction command, {
    String? relatedId,
    bool enabled = true,
  }) => OutlinedButton.icon(
    onPressed: !enabled || busy || !widget.repository.active
        ? null
        : () => perform(command, relatedId: relatedId),
    icon: Icon(icon, size: 17),
    label: Text(title),
  );

  Widget statusRow(String name, String value, {bool good = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          good ? Icons.check_circle_outline : Icons.info_outline,
          size: 18,
          color: good ? const Color(0xff168060) : const Color(0xff65748b),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(name)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget stepContent() {
    if (step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih layanan yang sudah ada atau buat layanan baru. Data yang tersimpan langsung menjadi bagian katalog ADMIN.',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(selectedId),
            isExpanded: true,
            initialValue: selected == null ? null : selectedId,
            decoration: const InputDecoration(
              labelText: 'Poliklinik / layanan',
            ),
            items: [
              for (final item in services)
                DropdownMenuItem(
                  value: '${item['id']}',
                  child: Text(
                    '${item['nama']} · ${item['kode']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => selectedId = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              action(
                'Tambah layanan',
                Icons.add,
                AdminSetupAction.createService,
              ),
              if (selected != null)
                action(
                  'Ubah layanan',
                  Icons.edit_outlined,
                  AdminSetupAction.editService,
                ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            statusRow('Mode reservasi', '${selected!['modeReservasi']}'),
            statusRow('Kategori', serviceCategoryLabel(selected!)),
            AdminServiceReadiness(
              catalog: catalog,
              serviceId: selectedId,
              today: widget.repository.api.config.today,
            ),
            statusRow(
              'Status layanan',
              selected!['aktif'] == true ? 'Aktif' : 'Nonaktif',
              good: selected!['aktif'] == true,
            ),
          ],
        ],
      );
    }
    if (selected == null) {
      return const Text('Pilih layanan di langkah pertama.');
    }
    if (step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ruang dan jadwal operasional menggunakan relasi layanan yang sama.',
          ),
          const SizedBox(height: 12),
          statusRow(
            'Ruang / loket aktif',
            '${rooms.where((r) => r['aktif'] == true).length}',
            good: rooms.any((r) => r['aktif'] == true),
          ),
          for (final room in rooms)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.meeting_room_outlined, size: 20),
              title: Text('${room['kode']} · ${room['nama']}'),
              subtitle: Text(room['aktif'] == true ? 'Aktif' : 'Nonaktif'),
            ),
          action('Tambah ruang / loket', Icons.add, AdminSetupAction.addRoom),
          const Divider(height: 24),
          statusRow(
            'Hari operasional aktif',
            '${hours.where((h) => h['aktif'] == true).length}',
            good: hours.any((h) => h['aktif'] == true),
          ),
          for (final row in hours)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined, size: 20),
              title: Text(
                '${row['hari']} · ${row['jamBuka']}–${row['jamTutup']}',
              ),
              subtitle: Text(
                'Kapasitas ${row['kapasitasHarian']} · ${row['aktif'] == true ? 'Aktif' : 'Nonaktif'}',
              ),
            ),
          action(
            'Atur hari operasional',
            Icons.event_repeat,
            AdminSetupAction.addHours,
          ),
        ],
      );
    }
    if (step == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gunakan profil dokter/tenaga layanan yang tersedia. Akun login tetap dikelola terpisah.',
          ),
          const SizedBox(height: 12),
          statusRow(
            'Profil terhubung',
            '${linkedDoctors.length}',
            good: linkedDoctors.isNotEmpty,
          ),
          for (final doctor in linkedDoctors)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text('${doctor['nama']}'),
              subtitle: Text('${doctor['spesialisasi'] ?? 'Tenaga layanan'}'),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              action(
                'Buat profil baru',
                Icons.person_add_alt_1_outlined,
                AdminSetupAction.createDoctor,
              ),
            ],
          ),
          if (otherDoctors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Hubungkan profil yang sudah ada',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final doctor in otherDoctors)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${doctor['nama']}'),
                subtitle: Text(
                  '${doctor['spesialisasi'] ?? 'Tanpa spesialisasi'}',
                ),
                trailing: action(
                  'Hubungkan',
                  Icons.link,
                  AdminSetupAction.linkDoctor,
                  relatedId: '${doctor['id']}',
                ),
              ),
          ],
        ],
      );
    }
    if (step == 3) {
      final walkIn = selected!['modeReservasi'] == 'ANTREAN_HARIAN';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            walkIn
                ? 'Layanan walk-in menggunakan kuota harian. Sesi praktik dan slot merupakan konfigurasi tambahan jika dibutuhkan.'
                : 'Sesi praktik bertanggal mengacu pada dokter terkait dan ruang. Slot dibuat untuk masing-masing sesi.',
          ),
          const SizedBox(height: 12),
          statusRow(
            'Sesi praktik dalam katalog',
            '${practices.length}',
            good: practices.any((p) => p['aktif'] == true),
          ),
          action(
            'Tambah sesi praktik',
            Icons.edit_calendar_outlined,
            AdminSetupAction.addPractice,
            enabled:
                linkedDoctors.isNotEmpty &&
                rooms.any((r) => r['aktif'] == true),
          ),
          if (linkedDoctors.isEmpty || !rooms.any((r) => r['aktif'] == true))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Hubungkan dokter dan sediakan ruang aktif terlebih dahulu.',
              ),
            ),
          const SizedBox(height: 12),
          for (final p in practices)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined, size: 20),
              title: Text(
                '${dateOnly(p['tanggal'])} · ${object(object(p['dokterLayanan'])['dokter'])['nama'] ?? 'Dokter tidak tersedia'}',
              ),
              subtitle: Text(
                'Ruang: ${object(p['loket'])['nama'] ?? 'Tidak tersedia'}',
              ),
              trailing: action(
                'Tambah slot',
                Icons.add,
                AdminSetupAction.addSlot,
                relatedId: '${p['id']}',
                enabled: p['aktif'] == true,
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Ketersediaan slot dan konflik jadwal tetap divalidasi server. Jumlah sesi bukan jumlah slot tersedia.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan ini berasal dari katalog ADMIN, bukan jaminan bahwa pelayanan sudah siap beroperasi.',
        ),
        const SizedBox(height: 12),
        statusRow(
          'Layanan',
          selected!['aktif'] == true ? 'Aktif' : 'Nonaktif',
          good: selected!['aktif'] == true,
        ),
        statusRow(
          'Ruang aktif',
          '${rooms.where((r) => r['aktif'] == true).length}',
          good: rooms.any((r) => r['aktif'] == true),
        ),
        statusRow(
          'Hari operasional aktif',
          '${hours.where((r) => r['aktif'] == true).length}',
          good: hours.any((r) => r['aktif'] == true),
        ),
        statusRow(
          'Dokter terkait',
          '${linkedDoctors.length}',
          good: linkedDoctors.isNotEmpty,
        ),
        statusRow(
          'Sesi praktik',
          '${practices.length}',
          good: practices.any((r) => r['aktif'] == true),
        ),
        const Divider(height: 28),
        const Text(
          'Penugasan PETUGAS, konflik ruang, ketersediaan slot, dan kesiapan display belum diverifikasi di langkah ini. Pengaktifan tetap mengikuti aturan backend.',
        ),
        const SizedBox(height: 12),
        action(
          'Periksa / ubah status layanan',
          Icons.settings_outlined,
          AdminSetupAction.editService,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      const names = [
        'Layanan',
        'Ruang & Jam',
        'Dokter',
        'Jadwal & Slot',
        'Ringkasan',
      ];
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.sizeOf(context).height * .90,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_tree_outlined,
                      color: Color(0xff4d63d9),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kelola Layanan Terpadu',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Konfigurasi bertahap menggunakan data existing',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < names.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${i + 1}. ${names[i]}'),
                          selected: step == i,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => step = i),
                        ),
                      ),
                  ],
                ),
              ),
              if (busy) const LinearProgressIndicator(minHeight: 3),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (error != null)
                        QueueBPopupNotice(
                          error!,
                          kind: QueueBFeedbackKind.error,
                        ),
                      stepContent(),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final buttons = <Widget>[
                      TextButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
                      OutlinedButton(
                        onPressed: busy || step == 0
                            ? null
                            : () => setState(() => step--),
                        child: const Text('Sebelumnya'),
                      ),
                      FilledButton(
                        onPressed: busy || step == 4 || selected == null
                            ? null
                            : () => setState(() => step++),
                        child: const Text('Selanjutnya'),
                      ),
                    ];
                    if (constraints.maxWidth <
                        420 * MediaQuery.textScalerOf(context).scale(13) / 13) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: buttons,
                      );
                    }
                    return Row(
                      children: [
                        buttons[0],
                        const Spacer(),
                        buttons[1],
                        const SizedBox(width: 8),
                        buttons[2],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
