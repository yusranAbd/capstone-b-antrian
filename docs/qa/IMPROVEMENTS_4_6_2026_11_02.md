# QueueB — implementasi inti poin 4–6 (2 November 2026)

**Pembaruan pemulihan dashboard, 2 November 2026:** kedua migration sudah diterapkan ke development lokal `127.0.0.1:5433/capstone_antrean`, setelah backup privat. Seluruh 10 migration selesai. Kolom kategori/referensi audit dan trigger notifikasi tersedia; pembacaan melalui Prisma untuk katalog, kesiapan, laporan operasional, akun dan sesi berhasil. Health API HTTP 200; akun/layanan/tiket tetap 7/4/4. Verifikasi ini hanya membaca data, tanpa simulasi antrean atau autentikasi baru. Runtime ekspor dan perilaku trigger/retensi/concurrency tetap belum diverifikasi. Bagian aktivasi di bawah merupakan status kode awal sebelum pemulihan ini.

## Hasil kode

4. **Notifikasi pasien:** tombol Beranda membuka inbox milik akun dengan pagination, jumlah belum dibaca dan aksi tandai dibaca. Pesan berasal dari peristiwa reservasi/status/panggilan nyata. Trigger menulis notifikasi dalam transaksi peristiwa, dengan ID sumber unik; rollback atau pengiriman socket ulang tidak menggandakan pesan. Feed pasien existing memperbarui inbox, tanpa koneksi socket kedua.
5. **Laporan operasional:** menu ADMIN `/admin/reports`, filter periode/layanan, pagination tampilan, ekspor PDF/CSV. Rekap memisahkan delapan status tiket terkini dan pasien unik. Rata-rata durasi memakai timestamp lengkap/nonnegatif dengan jumlah sampel; kosong tetap null. Pasien unik periode dihitung di database, bukan menjumlahkan pasien unik antarbaris. Periode maksimal 31 hari dan 5.000 baris; PDF maksimal 500 baris, CSV seluruh hasil filter.
6. **Aktivitas akun/sesi:** menu ADMIN `/admin/session-activity`, filter tanggal UTC/aksi/hasil/korelasi, pagination dan detail yang dapat disalin. Mencatat login, refresh, logout, pencabutan sesi pada ubah password/penonaktifan petugas, serta akses audit. Referensi akun/sesi/aktor adalah UUID acak terpisah dari ID autentikasi. Percobaan login gagal tidak dianggap dilakukan oleh pemilik akun sasaran. Header klien hanya klaim; sumber proses tetap UNKNOWN.

Tema, branding, komponen tabel/form, shell navigasi dan feed existing dipertahankan. Menu fitur ditambahkan tanpa perubahan global pada tema. Hasil request terlambat, dialog audit/inbox dan snapshot ekspor mengikuti scope akun; mengubah filter membersihkan hasil lama. Tidak ada perubahan pada prioritas antrean atau kontrak respons autentikasi.

## Validasi aktual

| Pemeriksaan | Hasil |
|---|---|
| Prisma generate dan validate | Berhasil; bukan penerapan migration |
| TypeScript API noEmit, tsconfig.build.json | Lolos pada kode akhir |
| Analisis Dart pada sembilan file berubah/baru | No issues found |
| Lima suite unit API (mock), termasuk regresi auth/profil | 29 lulus; 16,362 detik |
| Ulang suite audit sesudah pengetatan atribusi aktor | 4 lulus; 3,634 detik |
| Format Dart/TypeScript terkait | Selesai |
| git diff --check | Lolos; pemberitahuan konversi line ending tetap ada |

Unit mencakup kepemilikan/read-idempotency inbox, pagination, validasi periode, pasien unik ringkasan, penolakan truncation, allowlist/redaksi marker secret, kegagalan sink, hasil login yang tetap benar ketika audit gagal, serta regresi autentikasi dan perubahan password.

Tidak menjalankan build Web, suite Flutter menyeluruh, tes browser/perangkat, printer/dialog simpan nyata, ataupun tes database. Trigger PostgreSQL, agregasi SQL, rollback/concurrency dan retensi fisik belum dibuktikan melalui integrasi database. Jalur ekspor sudah melewati analisis Dart, tetapi hasil rendering PDF dan unduh CSV belum diuji saat runtime. CSV tersedia pada Web/desktop; platform mobile memakai PDF/share existing.

## Aktivasi dan batas

Migration aditif `20261102_notifications_and_session_audit` disiapkan dan **belum diterapkan**. Terapkan sesudah migration kategori `20261102_service_category`, sebelum menjalankan API terbaru. Migration menambah referensi korelasi, tabel audit dan trigger notifikasi; tidak membuat notifikasi historis atau merekonstruksi atribusi sesi lama. Tidak ada migration, seed, reset database, staging, commit atau push yang dijalankan dalam tugas ini.

Audit memakai sink terpisah, fail-open, maxWait 500 ms/timeout 1.000 ms. Gangguan sink menghasilkan warning generik dan dapat menyebabkan audit hilang; keberhasilan auth tidak diubah. Bacaan dibatasi retensi 30 hari; pembersihan fisik dilakukan oportunistik paling sering sekali per jam ketika aktivitas audit berikutnya terjadi. Retensi ini tidak menghapus sesi autentikasi. Histori AUTH-SESSION-01 tetap UNATTRIBUTED/FAIL.

Kontrak: [API Integration Guide](../backend/API_INTEGRATION_GUIDE.md). Rangkaian tes integrasi yang menulis database, bila dilanjutkan, harus menggunakan target test lokal dan cleanup fixture sesuai AGENTS.md.
