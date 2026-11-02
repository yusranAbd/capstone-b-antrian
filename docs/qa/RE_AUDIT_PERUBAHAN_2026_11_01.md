# Audit ulang perubahan QueueB — 1 November 2026

**Pembaruan:** F1–F6 dan temuan dokumentasi sudah ditangani. Verifikasi akhir: 1.358 tes lulus, 1 dilewati; analyze, format, dan build Web lulus. Lihat [catatan perbaikan tanpa redesain](PERBAIKAN_AUDIT_TANPA_REDESAIN_2026_11_01.md). Hasil di bawah adalah riwayat audit awal.

Status audit awal sebelum perbaikan: **ditemukan regresi; belum lulus quality gate**. Baseline perbandingan adalah HEAD lokal `6e0a015` dan perubahan working tree pada saat audit.

## Cakupan dan batas

Audit meninjau diff Flutter ADMIN, PASIEN, DOKTER, routing, dependency, tes yang berubah, serta file baru `admin_service_setup.dart`. Acuan: AGENTS.md, panduan UI/UX QueueB, dan kontrak integrasi API proyek. Folder Web tambahan diperiksa untuk keberadaan source dan petunjuk menjalankan aplikasi.

Tidak ada perubahan source produksi, stage, commit, push, migrasi, seed, atau pengujian yang menulis database. Empat reproduksi tambahan memakai mock HTTP; dua file tes sementara sudah dihapus setelah pengujian. Log audit dipertahankan di `apps/client/audit-*.log` (diabaikan Git). Audit ini tidak menggantikan pengujian backend/live, scanner fisik, atau browser lintas perangkat.

## Temuan fungsional

### F1 — P2: Jadwal Terdekat tidak diperbarui setelah kembali dari detail

Lokasi: [patient.dart:1543](../../apps/client/lib/src/patient.dart#L1543).

Alur: Reservasi → Buat Reservasi → Jadwal Terdekat → Pilih Jadwal → Kembali. Handler baru memanggil `booking.invalidate()`, menghapus service terpilih, kemudian kembali ke daftar tanpa memanggil `loadNearest()`. Invalidate mematikan `nearestActive`; `PatientBookingCubit.refreshSelection()` hanya memuat daftar terdekat bila flag tersebut aktif. Hydration route pencarian juga hanya mengatur mode.

Reproduksi mock mengubah slot menjadi penuh sesudah kembali lalu menjalankan refreshSelection: satu ReservationDoctorChoice lama tetap tampil, padahal seharusnya hilang. Ini masalah kesegaran informasi; pemilihan slot masih diperiksa ulang oleh alur existing.

Perbaikan: saat kembali ke mode nearest, baca ulang slot melalui owner existing dan pulihkan nearestActive; pertahankan query/filter pencarian.

### F2 — P2: Wizard menyembunyikan dokter dan sesi setelah item ke-12

Lokasi: [admin_service_setup.dart:181](../../apps/client/lib/src/admin_service_setup.dart#L181), [admin_service_setup.dart:205](../../apps/client/lib/src/admin_service_setup.dart#L205).

`otherDoctors.take(12)` dan `practices.take(12)` tidak disertai pencarian, pagination, atau tombol melanjutkan daftar. Dengan 13 dokter aktif yang belum terhubung, dokter ke-13 tidak dirender sehingga tidak dapat dihubungkan dari wizard. Sesi praktik setelah 12 pertama juga tidak memiliki aksi Tambah slot di wizard. Ini pemotongan dataset di UI, bukan pagination.

Reproduksi mock dengan 13 dokter memastikan dokter terakhir tidak ditemukan. Perbaikan: pagination atau pencarian yang menjangkau seluruh dataset; gunakan daftar lazy bila perlu.

### F3 — P2: Pemilik penyimpanan slot tidak mengikuti pilihan sesi pada form wizard

Lokasi: [admin.dart:358](../../apps/client/lib/src/admin.dart#L358).

Wizard membuka form dengan initialSession dan mengikat onSave ke `slotsById(relatedId!).save(body)`. Namun dropdown Jadwal Praktik tetap memuat seluruh sesi dan dapat diubah. Jika form berasal dari sesi A lalu pengguna memilih B, payload B masuk ke Cubit A. AdminSlotRepository.write menolak dengan 400 “Sesi slot tidak sesuai formulir.” Form menyediakan pilihan yang tidak dapat disimpan.

Temuan ini diverifikasi melalui penelusuran handler, pilihan form pada admin.dart:1027, dan guard AdminSlotRepository.write. Perbaikan: kunci sesi pada form khusus sesi atau pilih owner berdasarkan jadwalPraktikId payload, seperti alur editor utama.

### F4 — P2: Lebar tetap tabel bernomor menyebabkan overflow header

Lokasi: [admin_ui.dart:383](../../apps/client/lib/src/admin_ui.dart#L383), [admin_ui.dart:277](../../apps/client/lib/src/admin_ui.dart#L277).

Cabang baru DataTable memakai lebar tetap 880/980 menurut jumlah kolom. Lebar tersebut tidak menjamin header dan konten memperoleh ruang cukup. Tes admin_slot_widget_test “standalone adapter swaps session with old response still pending” membuktikan RenderFlex overflow 56 px pada header tabel; reproduksi existing memakai viewport 1100×1000. Tes tabel/penugasan admin lain juga menemukan overflow.

Perbaikan: ukur kebutuhan lebar kolom dan buat header adaptif, sambil mempertahankan horizontal scrolling. Verifikasi kembali tabel slot dan penugasan pada nama panjang serta text scaling.

### F5 — P2: Footer wizard overflow pada layar 320 px

Lokasi: [admin_service_setup.dart:274](../../apps/client/lib/src/admin_service_setup.dart#L274).

Tutup, Spacer, Sebelumnya, dan Selanjutnya ditempatkan pada satu Row tanpa adaptasi lebar. Reproduksi pada viewport 320×700, DPR 1, menghasilkan RenderFlex overflow 154 px ke kanan pada langkah pertama. Kontrol navigasi wizard keluar dari ruang dialog.

Perbaikan: gunakan Wrap atau susunan vertikal saat sempit dan uji kembali text scaling.

### F6 — P2: Drag mouse untuk mengganti tab beranda hilang

Lokasi: [patient_ui.dart:379](../../apps/client/lib/src/patient_ui.dart#L379).

PatientNativeHomeTabs menggantikan PatientHomeTabs tetapi menghilangkan ScrollConfiguration dengan PointerDeviceKind.mouse yang ada di implementasi sebelumnya. ScrollBehavior default tidak menjadikan drag mouse sebagai gesture scroll. Reproduksi gesture mouse pada TabBarView mempertahankan tab awal, padahal seharusnya pindah. Ketukan tab dan swipe sentuh merupakan jalur berbeda.

Perbaikan: pulihkan dukungan drag mouse pada TabBarView dan pertahankan isolasi gesture chip poliklinik.

## Tes dan quality gate

| Pemeriksaan | Hasil aktual |
|---|---|
| Format 21 file Dart yang berubah/baru, mode pemeriksaan tanpa menulis | **Gagal**: 12 file memerlukan format. Setelah hasil formatter, telemetry Dart juga melaporkan izin akses di luar workspace; file source tidak ditulis. |
| flutter analyze --no-pub | **Exit 1**, 3 info lint; tidak ada error/warning analyzer. |
| flutter test --no-pub --reporter expanded | **Exit 1**: 1.199 lulus, 152 gagal, 1 dilewati; 15 menit 21 detik. Tes live tanpa fixture dilewati. |
| Empat reproduksi audit dengan mock | Keempat assertion perilaku yang diharapkan gagal, membuktikan F1, F2 (dokter ke-13), F5, F6. Tidak termasuk hitungan suite utama. |
| flutter build web --no-pub | **Exit 0**, build/web berhasil; kompilasi 822,5 detik. Wasm dry run memberi peringatan dari flutter_tts 4.2.5 dan socket_io_common 3.1.1. Ini bukan bukti build Wasm berhasil. |
| git diff --check | Lulus. |

Tiga lint analyzer:

- admin_data.dart:852 — unnecessary_string_interpolations.
- admin_practice_form.dart:110 — curly_braces_in_flow_control_structures.
- test/patient_home_staff_test.dart:2 — avoid_relative_lib_imports.

Log: [suite utama](../../apps/client/audit-flutter-tests.log), [build Web](../../apps/client/audit-flutter-web-build.log), [tiga reproduksi UI](../../apps/client/audit-probes-final.log), [reproduksi nearest](../../apps/client/audit-nearest-probe.log). Log diabaikan Git dan tersedia pada checkout lokal ini.

**152 kegagalan tes tidak berarti 152 bug aplikasi yang berbeda.** Jumlah tersebut mencakup assertion/finder lama serta regresi layout dan alur. Tidak semua kegagalan dipastikan baru terhadap HEAD, karena audit ini tidak menjalankan suite pada checkout baseline terpisah. Enam temuan di atas ditautkan ke source yang berubah/baru dan diperiksa melalui reproduksi atau penelusuran kontrak owner/guard. CI saat ini belum dapat dinyatakan hijau: pipeline proyek memeriksa format, analyze, dan tes.


Kegagalan suite perlu dipilah sebelum memperbaiki kode. Contoh assertion yang tertinggal: patient_test_navigation.dart masih mencari NavigationDestination “Riwayat” dan opsi “Pilih Poliklinik”; patient_home_swipe_test.dart masih mencari key home-mode-appointment/home-mode-walkIn yang tidak dipasang pada widget baru; beberapa tes admin masih mengasumsikan PaginatedDataTable, sedangkan opt-in pagination kini memakai DataTable. Pembaruan tes harus mempertahankan assertion perilaku booking, QR, owner, refresh, dan aksesibilitas; jangan sekadar menghapus tes yang gagal.

## Dokumentasi yang tidak sesuai checkout

P3: [README.md:9](../../README.md#L9) menyatakan aplikasi React ADMIN/PETUGAS tersedia di apps/web dan menautkan apps/web/README.md serta docs/frontend/WEB_MVP.md. Kedua file tersebut tidak ada. Saat audit, apps/web/src, apps/web/tests, dan apps/web/public tidak berisi file source, dan root apps/web tidak mempunyai package.json. Klaim aplikasi Web siap dijalankan tidak dapat direproduksi dari checkout ini. README juga menyebut Flutter sebagai placeholder USER meskipun source empat portal tetap tersedia.

Perbaikan: sesuaikan status README dengan checkout aktual atau sertakan source/manifes serta petunjuk menjalankan aplikasi yang dimaksud.
