# Kliinik Kelompok B — Compact & Professional UI/UX Design System

Panduan mandiri untuk Flutter Kliinik Kelompok B. Ini menjadi acuan seluruh penyempurnaan visual berikutnya. Kebutuhan pengguna, keselamatan operasional, aksesibilitas dan kontrak aplikasi lebih utama daripada mengejar kepadatan atau dekorasi.

Nama tampilan aktif sejak 4 November 2026 adalah **Kliinik Kelompok B**,
sesuai ejaan yang diminta pengguna. Identitas publik Dart mengambil
`AppBrand` di `app_brand.dart`. Nama QueueB pada class, file, package,
protokol, dan catatan desain sebelumnya tetap sebagai identitas teknis atau
riwayat; perubahan nama tidak mengganti API, database, QR, atau autentikasi.

## Prinsip

**Simple, clean, compact, functional, consistent, responsive, accessible, performance-conscious.**

1. Dahulukan informasi dan tindakan yang dibutuhkan role. Satu halaman tidak perlu menampilkan semua fitur sekaligus.
2. Kurangi padding kosong dan tinggi minimum tanpa fungsi, bukan mengecilkan semua teks. Angka antrean aktif dan QR memiliki kebutuhan ukuran tersendiri.
3. Setiap nilai berasal dari API/state aktual; loading/tidak tersedia menggunakan penjelasan atau tanda —, bukan nol/estimasi palsu.
4. Gunakan komponen existing, radius dan spacing yang konsisten. Hindari ilustrasi generatif, ornamen, gradient atau bayangan baru tanpa fungsi. Aset branding existing tidak dihapus.
5. Gunakan tema per role; jangan mengubah tema dasar untuk memadatkan satu portal.
6. Ukuran di bawah adalah **logical pixels Flutter**, bukan piksel fisik. Hormati text scaling, SafeArea, keyboard dan zoom; jangan mematikan scaling untuk menyembunyikan overflow.

## Fondasi existing

| Fondasi | Sumber | Penggunaan |
|---|---|---|
| Palet/tema dasar | `apps/client/lib/src/mobile_ui.dart`, `QueueBStyle` | Branding dan komponen umum |
| ADMIN | `admin_ui.dart`, `AdminStyle`, `AdminTable`, `AdminRowActions` | Tabel/form operasional |
| PETUGAS | `staff_ui.dart`, `staff_v4.dart` | Daftar antrean, aksi pelayanan, One-Scan |
| DOKTER | `doctor_visual.dart`, `DoctorStyle` | Monitoring read-only |
| PASIEN | `patient_ui.dart`, `patient_home.dart`, `user_profile.dart` | Mobile, booking, tiket/QR/profil |
| Public Display | `display_board.dart`, `display.dart` | Monitor TV dan TTS |
| Container umum | `widgets.dart` (`Section`), `mobile_ui.dart` (`AppCard`, `EmptyState`) | Konten terstruktur, tanpa memaksakan tinggi tetap |

Tidak ada framework/dependency baru. Theme dasar tetap cached. `QueueBStyle.operationalTextTheme` adalah skala khusus portal operasional; bukan pengganti seluruh tema aplikasi. Override per role yang sudah proporsional tetap boleh dipertahankan.

<a id="pasien-dan-login-ruang-tenang"></a>

### Palet bersama seluruh portal: Biru Periwinkle

Revisi pengguna 28 Oktober 2026 mengganti palet Ruang Tenang dengan perpaduan biru/periwinkle, lavender muda, cyan dan putih dari referensi pengguna. Layout login dikembalikan ke kartu terpusat sebelum Final Experience (baseline f8baef8), tanpa panel editorial di kiri. Struktur compact pasien, lima navigasi, booking dan QR tetap dipertahankan. Perluasan persetujuan 28 Oktober 2026 menerapkan palet yang sama ke ADMIN, PETUGAS, DOKTER dan Public Display. Acuan warna bersama adalah `queueb_palette.dart`; tema tiap role tetap memiliki skala font/layout sendiri. `patient_design.dart` tetap menjadi tema khusus pasien. [QA seluruh portal](ALL_PORTALS_BLUE_PALETTE.md). [Catatan revisi](PATIENT_BLUE_PALETTE_REVISION.md). Laporan Final Experience sebelumnya merupakan riwayat, bukan palet aktif.

| Token bersama | HEX | Fungsi |
|---|---|---|
| Primary periwinkle | #4C60CC | Aksi utama, tab aktif, fokus |
| Hero blue | #4169D5 | Kunjungan terdekat, teks putih |
| Cyan | #007CA8 | Aksen sekunder berfungsi |
| Background lavender | #F2F5FF | Kanvas aplikasi |
| Paper | #FFFFFF | Card, form, dialog |
| Ink | #172544 | Informasi utama |
| Muted | #52617A | Metadata/caption dengan kontras |
| Border | #D9E1F2 | Pemisah, outline halus |
| Soft periwinkle | #EEF1FF | Pilihan/permukaan pendukung |
| Success | #2B674B | Dilayani/selesai |
| Waiting | #825400 | Check-in/menunggu |
| Danger | #A43946 | Dibatalkan/error |

Status tetap mengikuti API; `PatientDesign.statusInk/statusSurface/statusIcon` memisahkan DIPESAN, MENUNGGU, DIPANGGIL, DILAYANI, DILEWATI, SELESAI dan DIBATALKAN dengan label + ikon + warna. Teks normal pasangan tersebut diuji minimal 4.5:1. Jangan memperlakukan urutan warna sebagai algoritma antrean.

Font Material bawaan (Roboto pada Android), tanpa font/dependency/ilustrasi baru. Ikon launcher/favicon/PWA template diganti ekspor geometris QueueB; branding in-app existing dipertahankan. Heading mobile 20–22, judul card 14–16, body 14, fakta 13, caption 11–12 dengan kontras memadai; target sentuh 44–48. Nomor tiket 30–34 dan QR mempunyai skala tersendiri. Card mengikuti isi; tipografi tidak diperkecil menggunakan FittedBox untuk memaksa muat. Spacing 4/8/12/16/24, radius input/tombol 14 dan card 20–24, elevation ringan.

Lima navigasi pasien dan focus-scroll existing dipertahankan. Pada Beranda V6, branding dan sapaan tampil sekali di dalam konten yang ikut scroll; tanpa avatar, notifikasi backlog atau app bar kedua. Halaman lain tidak mendapat identitas tambahan. Agenda hanya memfilter tanggal appointment nyata, tiket memakai proyeksi terbaru, dan informasi teknis QR tidak mendominasi tampilan. Semua modal/picker menangkap tema dari scope USER di root, bukan mengubah theme global. Shared components membaca marker pasien untuk variasi komponen; seluruh role kini mengambil warna dasar yang sama dari QueueBPalette.

### Beranda pasien V6 — dua mode

Beranda memakai tab **Ambil Antrean** (default) dan **Janji Temu** melalui TabBar/TabBarView native, mendukung ketukan, swipe sentuh kiri–kanan dan drag mouse pada Web. Tab tetap terlihat setelah header digulir. Header, pencarian dan kunjungan terdekat tetap bersama; pilihan tab/filter dan posisi scroll per daftar dipertahankan melalui state/PageStorage existing. Chip poli memiliki gestur horizontal sendiri agar menggulir chip tidak memindahkan tab. Daftar tetap memakai sliver builder, tanpa fixed height untuk seluruh kartu. Kartu dokter menggunakan kembali PatientHomeDoctor sebelum V6: foto, spesialisasi/poli, jadwal aktual dan Detail Dokter. Beranda hanya menampilkan dokter dengan jadwal aktif pada tanggal pelayanan hari ini (Asia/Jakarta), bukan seluruh katalog dokter atau jadwal besok; kalender reservasi tanggal lain tetap tersedia melalui workflow existing. Lima tujuan bottom navigation tidak diganti.

Aksen Beranda kembali memakai palet periwinkle bersama: primary #4C60CC, hero #4169D5, soft #EEF1FF, background #F2F5FF dan putih. Kartu kunjungan dipulihkan ke komposisi sebelum V6 (baseline de56b16), dengan identitas dokter, badge status, nomor antrean dan fakta kunjungan. Nama/status/tanggal/ruang/nomor berasal dari proyeksi REST existing; kartu hilang seluruhnya bila tidak ada kunjungan relevan. QR berupa aksi untuk workflow penerbitan existing, bukan gambar QR dekoratif pada kartu.

Revisi 2 November 2026 memisahkan kategori tampilan dari kode dan mode booking melalui field API `kategori`. Ambil Antrean menampilkan kategori pendukung aktif (Pendaftaran, Apotek, Laboratorium, Radiologi, Kasir, Rekam Medis, dan Layanan lainnya) yang mendukung ANTREAN_HARIAN/HIBRIDA. Seluruh poliklinik tetap tampil di penjelajahan Janji Temu, termasuk poli ANTREAN_HARIAN; layanan pendukung dengan mode JANJI_TEMU_DOKTER juga dapat ditelusuri di sana. Label dan aksi mengikuti mode server, sehingga poli harian tidak dipaksa menjadi appointment. Pemetaan kode lama (termasuk DAFTAR) hanya menjadi fallback ketika respons belum memiliki kategori; perubahan kode tidak mengubah kategori tersimpan. Nilai mode tidak dikenal tidak diasumsikan dapat dipesan. Jangan menampilkan kuota tersedia atau estimasi dari keberadaan layanan saja. Klik membuka formulir/detail existing; mutasi tetap membutuhkan konfirmasi. [Implementasi dan QA V6](PATIENT_HOME_V6.md).

### Warna dan visual operasional

`QueueBStyle` mempertahankan nama alias existing (`teal`, `darkTeal`, `navy`, `mint`) demi kompatibilitas source, tetapi nilainya kini mengacu pada primary biru, ink dan soft dari QueueBPalette. Jangan menganggap nama legacy tersebut sebagai instruksi memakai teal lama. ADMIN memakai background/soft/cyan yang sama. Panel aksi PETUGAS dan live DOKTER memakai console #1D3270 sampai #314DA3 dengan teks putih/#E6EDFF; Public Display memakai hero #4169D5. Ukuran/font/grid tidak diubah. Status success/warning/danger operasional tetap memiliki warna semantik existing; jangan menggantinya dengan satu warna dekoratif.

- Warna status selalu didampingi label/ikon, tidak menjadi satu-satunya pembeda.
- Teks biasa target kontras minimal 4.5:1; teks besar dan kontrol bermakna minimal 3:1. Periksa kombinasi nyata, bukan menganggap seluruh warna token otomatis memenuhi semua konteks.
- Radius existing: operasional umumnya 14–16; pasien/card dasar 16–20; input 10–14. Pertahankan radius antar komponen sejenis, jangan memaksakan satu radius untuk seluruh role.
- Elevation rendah, border halus; hindari tumpukan bayangan tebal. Fokus keyboard harus terlihat.

### Spacing

Skala praktis: 4, 8, 12, 16, 20, 24. Token reusable: `smallSpace=8`, `mediumSpace=12`, `space=16`. Jadikan 8/12 gap komponen, 12/16 padding card, dan 16–24 margin luar desktop. Gunakan 16 margin horizontal mobile; pada 320px boleh 12 bila konten/touch target membutuhkan ruang. Jangan menetapkan tinggi card demi menyamakan tampilan bila isi berbeda.

## Skala portal operasional — ADMIN, PETUGAS, DOKTER

| Elemen | Baseline |
|---|---|
| Heading halaman | 18–22, semibold/bold |
| Heading section | 15–17 |
| Judul card | 14–16 |
| Body | 13–14 |
| Teks tabel/list | 12–14 |
| Metadata/timestamp/helper | 11–12, kontras cukup |
| Input/button | 13–14 |
| Header | 52–60; token baseline 56 |
| Baris tabel sederhana | 40–48, bertambah bila multiline/text scaling |
| Padding card | 12–16 |
| Gap | 8–12 |
| Margin halaman | 16–24 |

Statistik penting dapat lebih besar dari body bila membantu pemindaian cepat. Font 11–12 tidak dipakai untuk instruksi kritis atau pesan error panjang. Override operasional existing seperti metadata PETUGAS 11 dan label 12 boleh dipertahankan jika terbaca dan diuji; jangan mengubah semua angka hanya demi seragam.

`operationalTextTheme` menetapkan headline 20/22, title 14/15/17, body 12/13/14 dan label 11/12/13. Ini mencegah fallback headline Material 24–32 masuk ke card operasional. Ukuran eksplisit pada halaman lama tidak otomatis berubah; koreksi per halaman setelah ada bukti proporsi bermasalah.

### Penyempurnaan ADMIN — 2 November 2026

ADMIN memakai satu skala heading 22/17/15 dan body 13 dengan line height 1,4–1,45; tema di-cache khusus role. Branding/periwinkle bersama dan font Material existing dipertahankan. Panel memakai border ringan tanpa shadow dekoratif; sudut panel 16 dan input/tombol 10. Margin halaman 24 pada desktop, 16 pada layar kecil dan 12 pada lebar di bawah 360.

Judul, keterangan dan aksi halaman disusun melalui AdminPageHeading; aksi turun ke baris berikutnya pada viewport sempit atau teks diperbesar. Kelola Layanan Terpadu berada di header Dashboard. Kartu ringkasan menonjolkan nilai aktual dan jumlah aktif tanpa grafik/estimasi. Daftar layanan memakai pagination bernomor delapan baris dan menyembunyikan footer saat seluruh data sudah muat. Nama layanan dan kode dibedakan secara tipografi; status tetap label + warna/ikon. Navigasi mempertahankan seluruh tujuan langsung, dengan indikator aktif yang lebih tegas; sidebar desktop 232 dan mode ringkas 72. Search/filter memakai panel yang sama secara visual dengan tabel dan tetap Wrap saat sempit. [Implementasi dan batas verifikasi](ADMIN_MODERN_REFRESH_2026_11_02.md).

### Dashboard ADMIN — referensi 4 November 2026

Dashboard mengikuti komposisi gambar pengguna `Temp/screen.png` serta
`Temp/DESIGN.md`: header putih ringkas, sidebar berkelompok dengan menu aktif
biru, empat kartu KPI, grid monitoring layanan dan panel bawah dua kolom.
Kanvas lavender, panel putih radius 12, kontrol radius 8–10, ikon outline,
judul 16–22, body 13 dan metadata 11–12. Branding dan font Material existing
tetap digunakan. Sidebar desktop 248, collapsed 72; layar kecil memakai menu
existing. Konten panjang dapat scroll, grid beralih 4/2/1 kolom dan seluruh
layanan tetap dapat diakses melalui pagination.

KPI bersumber dari laporan operasional tanggal pelayanan hari ini:
`pasienUnik`, `dilayani`, `selesai`, `menunggu`. Unit pasien unik dibedakan dari
jumlah tiket. Waktu tunggu merupakan pengukuran server dengan jumlah sampel,
bukan perkiraan bagi antrean yang belum dilayani. Data belum tersedia diberi
tanda —. Cakupan kuota adalah layanan aktif dengan kapasitas positif pada hari
tersebut; numerator tiket tidak dibatalkan dan denominator kapasitas memakai
himpunan layanan yang sama. Kapasitas harian tidak dilabeli sebagai kapasitas
sesi dokter.

Kartu monitoring menampilkan ringkasan per layanan, jadwal serta ruang dan
profil/penugasan aktif yang sesuai. Dokter/petugas nonaktif tidak ditampilkan
sebagai penugasan saat ini. Aksi mengarah ke pengelolaan layanan, jadwal dan
ruang existing. Tabel bawah adalah **Aktivitas Layanan Hari Ini**, bukan log
CALL. Panel kanan memakai kelengkapan konfigurasi `/layanan/kesiapan` existing
dan pemakaian kapasitas harian. Sidebar mempertahankan seluruh tujuan dan
menambahkan pintasan Kelola Layanan Terpadu. Menu akun header memakai nama
dan avatar asli serta callback profil/logout existing.

Dashboard bersifat snapshot dengan muat ulang manual dan timestamp aktual.
Tidak mengklaim live 5 detik, operasional aktif, cloud latency, tren kemarin,
BPJS/P-Care, Super Admin, multi-fasilitas, nomor antrean per ruang atau alarm
kritis yang tidak disediakan kontrak ADMIN. CALL/RECALL/SKIP tetap milik
PETUGAS; RBAC, Queue Engine, API dan database tidak diubah.

Ekspor Laporan memakai PDF operasional existing dengan snapshot, tanggal,
identitas sesi dan guard navigasi. Pada tahap awal verifikasi dibatasi format
dan analyze terarah (0 masalah). Build Web gabungan kemudian diperbarui pada
revisi Janji Temu di bawah; ini bukan pengujian UI admin atau suite regresi.
Tidak ada commit atau push.

### Dokter ADMIN dan agenda praktik

Daftar Dokter memakai baris 64 logical px (bertambah mengikuti text scaling), identitas dan akun ringkas serta 6 baris per halaman; opsi jumlah baris dan seluruh menu aksi tetap tersedia. Bantuan alur profil/poliklinik/akun dipindahkan ke tombol Panduan dokter agar tidak menjadi banner permanen.

Jadwal Praktik memakai agenda per tanggal dan ruang, dengan 6 sesi per halaman, jam sebagai jangkar visual, pemilih tanggal, navigasi tanggal tersedia, Hari ini dan Semua tanggal. Semua tanggal tetap dapat diakses; bukan pemotongan data API. Pencarian/filter lama dan handler mutasi dipertahankan. Layar kecil/teks besar membungkus secara alami. [QA compact management](ADMIN_DOCTOR_PRACTICE_COMPACT.md).

## Skala mobile — PASIEN

Arahan Patient Home V8 (31 Oktober 2026) menggantikan komposisi Beranda V6/V7 dan lima menu publik yang dicatat sebagai riwayat di atas: gunakan header/logo existing, sapaan, asset gedung existing, kunjungan compact, segmented control dan kartu tiket kertas native berdasarkan referensi pengguna. Navigasi publik kini **Beranda, Riwayat, Informasi, Profil**. Route lama reservasi, tiket/detail/QR dan agenda tetap tersedia; Informasi memakai katalog/jadwal USER existing. Perubahan ini khusus PASIEN, tanpa mengganti tema global atau portal lain. [Spesifikasi implementasi dan QA V8](PATIENT_HOME_V8_REALISTIC_TICKET_REDESIGN.md).

| Elemen | Baseline |
|---|---|
| Heading | 18–22 |
| Judul card | 14–16 |
| Body | 14–16 |
| Caption | 12–13 bila terbaca |
| Padding horizontal | 16 |
| Gap | 8–12 |
| Target sentuh | sekitar 44–48, termasuk area hit |

Gunakan alur progresif pilih dokter/poli → jadwal → konfirmasi → tiket. QR harus utuh dengan quiet zone, dapat dibaca scanner, dan tidak diperkecil demi memuat lebih banyak konten. Tanggal, status dan lokasi harus jelas. Konten panjang boleh scroll; tombol utama jangan tertutup keyboard, navbar atau FAB. Jangan membawa font tabel desktop 12px ke seluruh body pasien.

### Referensi beranda pasien — 3 November 2026

Beranda Ambil Antrean dan Janji Temu mengikuti referensi pengguna dari
`stitch_queueb_mobile_ui_redesign`. Revisi terakhir pengguna 4 November 2026
memakai kembali komposisi kompak dari DESIGN.md: kartu sapaan putih, ikon
tas medis outline, pencarian ringkas, dan banner kunjungan dengan lonceng.
Sapaan, pencarian dan kunjungan terdekat berada di atas pada kedua mode.
Tab **Ambil Antrean / Janji Temu** berada di bawah
bagian tersebut, lalu tetap pinned ketika header konten digulir. Branding QueueB,
font Material, navigasi, satu controller tab, swipe, dan state filter existing
tetap digunakan. Card memakai sudut semi kotak dan tinggi mengikuti konten.

Beranda dibatasi 480 logical px pada layar lebar, dengan margin 16. Header
normal 64, tab minimal 48, kartu radius 12 dan kontrol radius 8–10. Sapaan
20, judul layanan 18, judul bagian 16, isi 13–14 dan metadata 11–12;
nomor tiket dalam kartu ringkas 22–26 dan jumlah menunggu 24. Font Material
dan branding existing tetap dipakai; tidak ada dependency/font/aset baru.
Foto dokter beranda 44 dengan sudut 8. Ikon navigasi memakai outline:
rumah, kalender check, informasi, dan profil. Semua ukuran tetap mengikuti
text scaling; layar sempit/teks besar membungkus atau beralih susunan.

Gesture ke atas yang menggulir konten ke bawah menyembunyikan header dan
navbar; arah balik menampilkannya. Boundary scroll Beranda dihitung dari
header luar serta daftar tab aktif, bukan offset nol salah satu viewport.
Scroll horizontal/programmatic tidak memicu hide. Fokus pencarian, navigasi
aksesibel native, pergantian halaman dan posisi teratas memulihkan chrome.
Listener fokus serta input Web tetap dilepas saat dispose. Tombol konfirmasi
detail dokter tetap terlihat sesuai kontrak halaman tersebut.

Kartu walk-in memisahkan nomor pribadi/pelayanan dari sisi **Sisa antrean**
(`waitingCount`). Angka kumulatif tetap berlabel **check-in hari ini**, bukan
jumlah pendaftar. **Lihat Status** membuka tiket milik pasien; **Ambil Nomor**
memakai alur registrasi existing. Nomor pelayanan beberapa ruang tetap utuh.
Kartu dokter menampilkan foto, spesialisasi, poli, jadwal/ruang aktual dan
**Detail & Jadwal**. Ketersediaan slot, BPJS, badge verifikasi, status buka
fasilitas, dan ETA contoh tidak diasumsikan tersedia dari data beranda.

Revisi kompak awal hanya diformat sesuai arahan sebelumnya untuk pekerjaan
visual. Build Web gabungan kemudian diperbarui bersama revisi Janji Temu di
bawah. Tidak ada pengujian UI otomatis atau perubahan API/database, commit
atau push; hasil CI lama bukan bukti regresi untuk revisi terbaru.

### Pemadatan tab Janji Temu — 4 November 2026

Revisi lanjutan Janji Temu memakai skala panduan desain yang telah diberikan:
nama dokter 15 semibold, metadata 12, foto 40 dengan radius 8, padding kartu
10 dan gap 6–8. Spesialisasi/poli hanya ditampilkan sekali. Jadwal dan ruang
digabungkan dengan CTA **Detail & Jadwal** dalam satu footer; pada layar
sempit atau teks besar tombol pindah baris tanpa memotong informasi.

Filter layanan tetap horizontal dengan target sentuh native dan label 12.
Heading **Dokter Hari Ini** memakai tanggal ringkas aktual, agar tidak
memaksa baris kedua. Jarak ganda antara kartu terakhir dan bantuan jadwal
dihilangkan; bantuan tetap membuka chooser reservasi existing. Sapaan,
pencarian serta kunjungan terdekat tetap pada header bersama **di atas tab**
(`tabsFirst: false`), bukan dipindahkan ke dalam daftar Janji Temu.

Callback pemilihan dokter, pemeriksaan revisi/route/mounted, filter, lazy list,
realtime dan pembatasan mode reservasi tidak diubah. Tidak ada mutasi database,
commit atau push. Preview Web telah diperbarui dengan build JavaScript release
(`--no-pub --no-wasm-dry-run`) pada 4 November 2026, 12:12:45 waktu host.
Build berhasil dalam 101 detik; HTML, main.dart.js dan health API merespons
HTTP 200. SHA-256 aset yang disajikan HTTP cocok dengan file build. Preview
`http://127.0.0.1:5175/` tetap mengarah ke API simulasi lokal port 3003 dengan
zona Asia/Jakarta. Tab browser lama memerlukan Ctrl+Shift+R. Tidak dilakukan
pengujian UI otomatis; keberhasilan build bukan verifikasi visual/runtime
semua interaksi.

### Referensi detail dokter pasien — 4 November 2026

Detail Dokter mengikuti referensi pengguna `stitch_queueb_mobile_ui_redesign (2)`:
header putih dengan kembali/profil, kartu identitas putih semi kotak, foto dari
media dokter existing, kalender tanggal dan bulan, kartu sesi, grid jam, dan
informasi kedatangan. Status menyatakan **jadwal** praktik, bukan kehadiran
dokter. Rating, SIP, pengalaman, badge verifikasi, serta aturan kedatangan
contoh tidak ditambahkan tanpa sumber data.

Pada detail janji temu, navigasi bawah sementara menjadi ringkasan tanggal/jam
terpilih dan tombol **Konfirmasi Janji** yang tetap terlihat saat scroll.
Navigasi pasien empat tujuan tetap tersedia pada halaman lainnya; tombol
kembali mempertahankan asal pencarian/layanan. Bar menggunakan SafeArea dan
ruang layout Scaffold, sehingga tidak menimpa konten. Susunan bar dan grid
beradaptasi terhadap lebar serta text scaling. Kalender hanya menampilkan
tanggal praktik yang bersumber dari API; bulan/tanggal tidak membuat data slot.

Pergantian tanggal tetap membuang pilihan sesi/slot lama. Konfirmasi hanya
aktif untuk slot dari sesi/tanggal terpilih yang aktif, tersedia dan tidak
habis kapasitas. Aksi meneruskan dialog review dan Cubit pemesanan existing.
Layanan ANTREAN_HARIAN tidak mendapat tombol booking slot dokter. Profil,
tentang dokter, jadwal, retry, route dan kontrak API tetap memakai sumber asli.

Pada implementasi awal, verifikasi dibatasi format sesuai arahan pengguna
saat itu. Pemadatan dan hasil verifikasi terbaru dicatat pada bagian berikut;
perilaku runtime dan hasil visual belum diuji. Tidak ada commit atau push.

### Referensi halaman reservasi pasien — 4 November 2026

Daftar Reservasi Pasien mengikuti referensi pengguna terbaru: header/logo
existing, pencarian dengan filter status, chip horizontal, kartu kunjungan
putih dan tombol **Buat Reservasi Baru** di akhir daftar. FAB pembuatan
reservasi pada halaman ini diganti tombol dalam alur konten agar tidak
menutup kartu. Pencarian, pull-to-refresh, lazy list, scroll controller dan
state filter tetap dipertahankan saat data diperbarui.

Kartu mengutamakan layanan, dokter bila tersedia, nomor/kode tiket asli,
tanggal, jam dan ruangan yang tersedia. Status tiket tetap otoritatif;
**Berlangsung** memfilter status operasional pada hari ini. **Riwayat**
mencakup status terminal dan kunjungan dengan tanggal yang telah lewat,
tanpa mengubah status tiket tersebut menjadi Selesai. Angka header berasal
dari koleksi milik pasien; data yang belum terverifikasi ditandai —.

Ringkasan nomor pelayanan hanya memakai proyeksi antrean existing dengan
layanan dan tanggal yang cocok; tidak ada langganan atau endpoint tambahan.
Kartu membedakan Live, data terakhir, dan belum tersedia, tanpa mengarang
urutan/estimasi sisa antrean. Pembukaan tiket/QR, pengecekan otorisasi serta
konfirmasi pembatalan tetap melalui callback existing. Aksi Ubah Jadwal
atau bukti kunjungan baru tidak dibuat hanya karena ada pada contoh desain.

Pada implementasi awal, verifikasi dibatasi format sesuai arahan pengguna
saat itu. Pemadatan dan hasil verifikasi terbaru dicatat pada bagian berikut;
hasil runtime/visual belum diuji. Tidak ada commit atau push.

### Pemadatan detail dokter dan reservasi — 4 November 2026

Revisi lanjutan kedua halaman mengikuti DESIGN.md dan gambar pengguna dengan
skala yang sama seperti tab Janji Temu. Konten pasien terpusat maksimal 480
logical px, margin horizontal 16, kartu radius 12 dan jarak antarkomponen 8.
Perubahan ini dibatasi ke detail dokter serta daftar reservasi; tema global,
portal operasional dan alur reservasi lainnya tidak diperkecil.

Detail dokter memakai foto 56, nama 18, metadata 12–13 dan padding 12.
Kalender memakai tanggal selebar 60 pada skala normal, angka 22, serta tinggi
yang dihitung dari text scaling. Label bulan dapat membungkus dan tanggal
terpilih diungkap ulang saat ukuran teks berubah. Kartu sesi menampilkan jam,
zona waktu dan ruang aktual; grid slot memiliki minimum 78 dan tetap tumbuh
sesuai isi. Header 60, panel kedatangan 13, serta bar konfirmasi ringkas dengan
target sentuh 48. Pilihan sesi/slot, guard dan dialog review tidak diubah.

Daftar reservasi memakai heading 20, judul layanan 16, nama dokter/isi 13,
metadata 12 dan label status 11. Kartu padding 12, panel jadwal/antrean 10,
jarak kartu 8, pencarian 13 dan filter native yang ringkas. Tombol tetap
memiliki area sentuh 44–48, dapat berpindah baris dan mengikuti text scaling.
Pencarian/filter tersimpan, lazy list, refresh, status tiket otoritatif,
proyeksi antrean, izin QR dan konfirmasi pembatalan tetap memakai alur asli.
Tidak ada SIP/rating/pengalaman, aturan kedatangan, estimasi, atau aksi ubah
jadwal baru yang diambil dari data contoh pada gambar.

Keempat file UI telah diformat. Flutter analyze terarah pada keempat file
selesai tanpa masalah (14,4 detik setelah memperbaiki satu saran linter).
Tidak ada pengujian UI, mutasi database, commit atau push dalam revisi ini.
Build Web release JavaScript (`--no-pub --no-wasm-dry-run`) berhasil dalam
99,1 detik; aset diperbarui 4 November 2026 pukul 13:05:54 waktu host.
Preview `http://127.0.0.1:5175/`, main.dart.js dan health API simulasi lokal
port 3003 merespons HTTP 200; SHA-256 aset HTTP cocok dengan file build.
Tab browser lama memerlukan Ctrl+Shift+R. Keberhasilan kompilasi serta
pemeriksaan aset bukan bukti verifikasi interaksi atau hasil visual UI.

## Standar Public Display

Public Display **tidak memakai skala dashboard desktop**. Pertahankan skala responsive di `DisplayBoard`: nomor panggilan sangat besar, nama poli/jam jelas, lokasi tujuan kuat, daftar pasien terbaca, kontras tinggi. Nomor daftar tidak boleh terpotong menjadi ellipsis; gunakan ruang kolom yang cukup dan scale-down untuk kode panjang.

- Monitor 1280×720, 1366×768, 1440×900, 1920×1080: tanpa scroll atau overflow.
- Kapasitas list mengikuti tinggi; daftar panjang memakai auto-pagination existing, bukan memperkecil semua teks atau membuat scroll.
- Empty/loading/reconnect/rejected harus dibedakan. Akses ditolak tidak mempertahankan snapshot sensitif.
- REST snapshot adalah sumber kebenaran; namespace /display, deduplikasi peristiwaId, pairing per perangkat, kebijakan nama server dan TTS existing tidak berubah karena pekerjaan visual.
- Kontrol audio/fullscreen/perangkat tidak mendominasi layar; tetap dapat ditemukan dan dioperasikan.
- Preview sempit boleh memakai skala monitor; bukan UI operasional ponsel baru. Uji speaker/id-ID di perangkat fisik sebelum pemasangan.

## Standar komponen

| Komponen | Aturan |
|---|---|
| AppBar/header | Tinggi operasional 56; brand/identitas secukupnya, nama panjang ellipsis + akses profil. Pada sempit sederhanakan isi, jangan menumpuk semua tombol. |
| Sidebar | Pertahankan item/group existing, indikator aktif jelas, label singkat. Beralih Drawer sesuai breakpoint existing; jangan menambah sidebar pada DOKTER/PETUGAS. |
| Card/Section | Padding 12–16, judul 14–17, gap konten 8–12, tinggi mengikuti isi. Gunakan Section/AppCard existing; bukan panel kosong dengan minHeight besar. |
| Tabel | 40–48 untuk baris sederhana, header 40–44, text 12–14. Izinkan tinggi adaptif untuk multiline/scaling. Pagination existing, kolom numerik selaras, status jelas. Scroll horizontal **terbatas di tabel** boleh untuk kolom yang benar-benar banyak; jangan membuat root halaman melebar. |
| Dropdown Aksi | Gunakan `AdminRowActions` existing; ikon 18–20, tooltip/label jelas, aksi berbahaya merah dan konfirmasi. Jangan menambah/menghilangkan aksi atau mengubah arti Nonaktifkan/Hapus. |
| Search | Lebar fleksibel, ikon 18–20, hint singkat sesuai field yang benar-benar dicari. Jangan menjanjikan pencarian medis/data yang tidak didukung API. |
| Filter | Dekat pencarian, Wrap/stack pada sempit, nilai pilihan terlihat. Pertahankan filter setelah refresh/mutasi bila state existing mendukung. |
| TextField/dropdown | Desktop padding horizontal 12/vertical 10; mobile tetap target nyaman. Label persisten, helper/error dapat membungkus; input kode/token tidak dicetak pada log. |
| Button | Primer untuk aksi utama, outline/text untuk sekunder. Tinggi visual desktop sekitar 36–44, target hit/touch 44–48 bila digunakan dengan sentuhan. Jangan paksa label panjang satu baris pada lebar sempit; pindahkan/stack tombol. |
| Dialog | Lebar terbatas sesuai formulir, judul/isi/action jelas. Isi panjang dapat scroll dalam viewport, tombol tidak tertutup keyboard. Pertahankan validasi dan konfirmasi. |
| Bottom sheet | Mobile: SafeArea dan inset keyboard, isi dapat scroll, tinggi berdasarkan kebutuhan. Pilihan utama jelas dan tombol tutup dapat dijangkau. |
| Status badge | Teks + warna/ikon, padat, label konsisten dengan status existing. Jangan mengubah state machine melalui label visual. |
| Avatar | Header operasional sekitar 28–36; mobile 36–48; identitas card 40–64 bila perlu. Fallback inisial/icon; jangan menganggap ilustrasi sebagai foto akun. |
| Empty state | Pesan singkat + aksi bila tersedia, ikon kecil 28–36, padding 12. Hindari ilustrasi besar atau vertical spacer berlebihan pada dashboard. |
| Loading | Indikator sesuai area data; pertahankan data valid terakhir bila kontrak mengizinkan. Hindari spinner yang mengunci seluruh layar pada refresh ringan. |
| Error/reconnect | Pesan spesifik + retry, teks membungkus, jangan hanya warna. Loading/kosong/akses ditolak dibedakan; jangan bocorkan credential/detail internal. |
| FAB | Hanya bila ada aksi primer nyata; jangan menutup baris terakhir, tombol batal, atau bottom navigation. Beri bottom inset konten yang cukup. |
| Bottom Navigation | Gunakan `PatientBottomNavigation` khusus PASIEN, empat tujuan V8: Beranda, Riwayat, Informasi, Profil. Tinggi mengikuti label/text scaling dan SafeArea; mapping menu ke branch eksplisit, bukan menghapus indeks route lama. Booking appointment tetap melalui segmented control Beranda dan route legacy. Jangan mengubah navbar/tema portal lain. |

## Perbedaan lima portal

- **ADMIN:** kepadatan tabel, CRUD, search/filter/form. Informasi nama/status utama; identifier teknis tidak menjadi input manual bila ada pilihan data.
- **PETUGAS:** antrean dan aksi pelayanan adalah fokus. Panel pelayanan cukup dominan; QR One-Scan dibuka lewat FloatingActionButton.extended Pindai QR, tanpa panel bawah/input manual. Sisakan inset bawah agar FAB tidak menutupi aksi terakhir; dokter terjadwal dan status antrean tetap terlihat. Urutan/prioritas mengikuti server.
- **DOKTER:** monitoring jadwal/appointment/antrean read-only. Jangan menambahkan aksi pelayanan PETUGAS, rekam medis, atau data pasien yang tidak tersedia.
- **PASIEN:** mobile-first, navigasi sederhana, booking/reservasi/tiket/QR. Jangan mengorbankan touch target/teks demi kepadatan desktop.
- **PUBLIC DISPLAY:** informasi jarak jauh, tanpa scroll, pengumuman aktual, privasi dan keamanan perangkat.

Login memakai kartu terpusat pada desktop dan mobile sesuai revisi 28 Oktober 2026. Lebar maksimum 420, scroll ketika viewport/keyboard/text scale membutuhkannya. Tidak ada panel editorial baru. Jangan mengubahnya saat memadatkan portal operasional lain.

## Audit fondasi dan keputusan tahap ini

| Temuan | Koreksi terarah |
|---|---|
| ADMIN/DOKTER mewarisi typography Material dasar; title/headline dapat lebih besar daripada kebutuhan card | Pasang `operationalTextTheme` khusus tema operasional. PETUGAS mengambil baseline sama sambil mempertahankan override compact existing. |
| Section umum padding 20, title-body gap 16, gap action 20 | Padding 16, title-body gap 12, gap action 12/runSpacing 8. Tidak mengubah isi, callback, atau mode scroll. |
| EmptyState umum padding vertikal 20, ikon 36, gap 12 | Padding 12, ikon 32, gap 8. Pesan/aksi tetap. |
| AdminTable sudah memakai baris 44–48 dan padding tabel compact | Pertahankan; jangan mengecilkan ulang. |
| Pasien sudah memiliki navbar 60 terpisah; input/tombol dasar 48 dan padding 16 | Pertahankan; jangan ubah global demi dashboard. |
| Public Display baru selesai dipoles dan mempunyai skala sendiri | Bersihkan komentar saja; tidak mengecilkan nomor, row, kartu ruang, atau kontrol. |
| Revisi compact DOKTER lokal belum di-commit | Pertahankan; commit tugas ini hanya komentar dan wiring tema yang disetujui, tanpa membawa revisi layout lokal. |

Ini pembenahan fondasi, bukan klaim semua halaman/hardcoded style langsung seragam. Polishing selanjutnya harus berbasis masalah nyata dan memakai dokumen ini.

## Responsive, aksesibilitas dan performa

Wajib periksa desktop **1280×720, 1366×768, 1440×900, 1920×1080**; mobile **320×568, 360×800, 390×844, 412×915**. Uji text scale minimal 1.0 dan skenario teks diperbesar pada komponen yang berubah.

- Tidak ada RenderFlex overflow, tabrakan kontrol atau root horizontal overflow. Konten panjang scroll wajar; tabel dapat scroll terkontrol, TV tetap tanpa scroll.
- Gunakan Expanded/Flexible/Wrap dan constraints yang sesuai; jangan menyembunyikan error dengan clipping atau mematikan text scaling.
- Label panjang, error jaringan, empty/loading, data padat dan status aktual perlu diuji, bukan hanya screenshot ideal.
- Fokus keyboard, semantics/tooltip pada ikon, urutan navigasi dan kontras tetap jelas. Jangan hanya menggunakan hover untuk aksi penting.
- Reuse ThemeData/tokens cached. Jangan mengganti daftar berpaginasi dengan seluruh row sekaligus, memperbesar image decode tanpa perlu, atau membocorkan timer/listener/controller.
- Pertahankan coalescing REST snapshot, reconnect, deduplikasi TTS dan disposal existing. Optimasi ukuran aplikasi dan realtime tidak boleh dikorbankan untuk dekorasi.

## Workflow dan definition of done

1. Baca panduan ini, kontrak API bila relevan, dan pemilik komponen yang akan diubah.
2. Periksa Git serta pekerjaan lokal; stage hanya file/hunk terkait. Ikuti workflow Git yang disetujui pengguna, bukan membuat branch/PR/merge otomatis.
3. Jelaskan masalah ukuran yang terbukti; perubahan harus sekecil yang menyelesaikannya. Jangan mengubah API/backend/database/RBAC untuk perapihan visual.
4. Jalankan format file berubah, flutter analyze, tes layout/interaksi/regresi relevan dan build Web. Catat viewport, hasil aktual, serta batas hardware/browser yang belum diuji.
5. Periksa diff, data/screenshot sintetis dan keamanan file; jangan commit .env, profil browser, credential, backup atau perubahan lokal tak terkait.
6. Setelah push yang disetujui, periksa CI pada SHA yang tepat. Screenshot dan test tidak menggantikan pemeriksaan readability manusia.

Pemeliharaan panduan: perubahan token harus disertai alasan, scope role, dan verifikasi. Tidak memakai skor desain generik atau dependensi panduan eksternal.
