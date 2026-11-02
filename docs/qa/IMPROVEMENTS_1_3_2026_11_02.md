# QueueB — implementasi inti poin 1–3 (2 November 2026)

**Pembaruan pemulihan dashboard, 2 November 2026:** migration kategori dan notifikasi/audit sudah diterapkan pada development lokal `127.0.0.1:5433/capstone_antrean` setelah backup. Dashboard sebelumnya gagal karena kolom baru belum tersedia. Jumlah akun/layanan/tiket tetap 7/4/4 sebelum dan sesudah migrasi; pembacaan katalog/kesiapan layanan berhasil dan health API HTTP 200. Bagian aktivasi di bawah mencatat status implementasi kode awal, sebelum pemulihan ini.

## Hasil kode

1. Kategori layanan disimpan eksplisit, dapat diatur ADMIN, dan dipakai untuk kategori/urutan Beranda. Kode layanan dapat berubah tanpa mengubah kategorinya. Respons lama tetap mengenali alias DAFTAR dan APOTIK.
2. Tabel layanan dan Kelola Terpadu menampilkan kelengkapan dari API ADMIN beserta rincian kekurangan. Penilaian mencakup ruang, jam/kapasitas, penugasan hari ini, dan khusus mode janji temu/hibrida: dokter, sesi, serta slot yang valid dan belum berakhir. Layanan harian tidak diwajibkan memiliki dokter. Hasil merupakan konfigurasi saat diperiksa, bukan informasi kehadiran atau jaminan kuota.
3. PETUGAS ruang terkait dapat membatalkan appointment MENUNGGU setelah sesi berakhir pada tanggal pelayanan hari ini, melalui menu tiket dan pilihan alasan wajib. Status/versi diperiksa ulang di transaksi dan audit menyimpan aktor serta alasan. Notifikasi sesudah commit memperbarui portal terkait tanpa TTS baru.

Tema, susunan portal, prioritas CALL, QR check-in, dan workflow pemesanan menggunakan komponen/alur existing. Perubahan tampilan terbatas pada field kategori, kolom/indikator kelengkapan, dan menu/dialog pembatalan.

## Validasi aktual

| Pemeriksaan | Hasil |
|---|---|
| Prisma generate dan validate | Berhasil; tidak mengubah database |
| TypeScript API, tsconfig.build.json, noEmit | Lolos |
| Analisis Dart pada 16 file yang disentuh | No issues found |
| Unit API dengan mock, dua suite baru | 13 lulus, sekitar 21 detik |
| Format Dart dan TypeScript terkait | Selesai |
| git diff --check | Lolos; terdapat pemberitahuan konversi line ending dari Git |

Tes unit memeriksa layanan harian tanpa dokter, kekurangan hibrida, alias kategori, pembatasan petugas/ruang/tanggal/status/sesi, alasan wajib, konflik versi, audit, dan broadcast setelah keberhasilan. Pengujian ini tidak membuktikan perilaku transaksi/concurrency PostgreSQL melalui integrasi nyata.

Build Web, regresi menyeluruh, pengujian UI browser, dan tes database tidak dijalankan untuk menjaga pemeriksaan tetap singkat sesuai permintaan. Tidak ada commit, push, atau staging.

## Aktivasi database terpisah

Migration `apps/api/prisma/migrations/20261102_service_category/migration.sql` sudah disiapkan dan **belum diterapkan**. API terbaru membutuhkan kolom ini sebelum dijalankan. Deployment berikutnya perlu menerapkan migration melalui alur Prisma proyek, lalu menjalankan API/client yang sesuai. Data yang kategorinya tidak dapat disimpulkan dari kode lama mendapat POLIKLINIK; ADMIN dapat mengubahnya dari formulir layanan.

Tidak ada perubahan data development/production dalam pekerjaan ini. Pembatalan otomatis, penjadwalan ulang, dan perpanjangan sesi berada di luar implementasi ini.

Kontrak endpoint dan kebijakan: [API Integration Guide](../backend/API_INTEGRATION_GUIDE.md).
