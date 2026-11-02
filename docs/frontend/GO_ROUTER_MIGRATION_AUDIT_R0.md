# QueueB Hospital — R0 Routing Architecture Audit

Tanggal audit: **29 Oktober 2026**, host Windows, timezone pengguna Asia/Jayapura; **timezone pelayanan tetap Asia/Jakarta**. Status: **READY WITH CONDITIONS**. Ini audit source dan blueprint, **bukan implementasi go_router**.

## A. Executive Summary

Routing sekarang merupakan kombinasi **Navigator 1.0, pemilihan portal melalui QueueApi, dan state navigasi lokal**. Ada satu entry point produksi, satu `MaterialApp`, root implisit `/`, dan satu route bernama eksplisit `/display`. Sembilan modul ADMIN dan lima tab PASIEN tidak mempunyai URL masing-masing. Profil lintas role dipush sebagai `MaterialPageRoute` anonim; scanner dan berbagai detail/editor memakai dialog. Belum ada `MaterialApp.router`, go_router, nested Navigator proyek, atau guard URL deklaratif.

Rekomendasi untuk R1–R3:

- Satu GoRouter yang dibuat sekali selama aplikasi hidup; QueueApi/SessionStore tetap sumber sesi. Tidak menambah AuthCubit/session store kedua.
- ADMIN: satu `ShellRoute`, sembilan URL modul, ownership katalog/Cubit tetap di atas pergantian modul.
- PASIEN: rekomendasi **`StatefulShellRoute.indexedStack` dengan lima branch lazy**, setelah kontrak Back/tab pada F disetujui. Ini menambah kemampuan stack per tab; **bukan** kemampuan yang sudah ada. Hindari membuat lima PatientRepository atau lima PatientPage lengkap.
- PETUGAS dan DOKTER: `GoRoute` biasa dengan child profil, tanpa shell tambahan yang tidak dibutuhkan.
- PUBLIC DISPLAY: satu `GoRoute('/display')` dengan owner perangkat/monitor stabil, terpisah dari redirect akun. Pairing, reject, restore dan monitor tetap state dalam host yang sama.
- Pertahankan strategi URL **hash** pada implementasi awal. PathUrlStrategy memerlukan verifikasi hosting/fallback tersendiri.
- Modal konfirmasi, QR, kamera dan activation code tidak wajib menjadi URL. Deep link tiket harus memulihkan data melalui GET yang sah dan **tidak otomatis menerbitkan QR/POST**.

### A1. Preflight dan batas bukti

| Pemeriksaan | Hasil aktual R0 |
|---|---|
| Branch | `main` |
| HEAD lokal dan origin/main setelah fetch | `2babd1860b9b80426ecfffaf408b7bd7a24d9110`, 0 ahead / 0 behind |
| Pemeriksaan akhir ref remote | HEAD lokal tetap `2babd18`; origin/main kemudian `17e8653b82ea25dc2f14ec5e6c1a8da08ec0fc77`, lokal behind 1. Delta hanya `CONTRIBUTING.md` (`Update CONTRIBUTING.md`), tidak ada perubahan source routing. Tidak melakukan pull/merge; R1 wajib preflight ulang |
| CI baseline | [CI 40843308000 sukses untuk SHA tersebut](https://github.com/yusranAbd/capstone-b-antrian/actions/runs/40843308000) |
| Perubahan tracked sebelum audit | README.md, doctor_dashboard.dart, doctor_visual.dart, doctor_visual_refresh_test.dart; tidak disentuh |
| Untracked sebelum audit | `apps/web/`, `backups/`, `sql/`, dokumen/illustrasi review dokter, serta `docs/setup/LOCAL_INSTALLATION_GUIDE.md`; dipertahankan |
| Perubahan yang diizinkan R0 | Hanya dokumen ini; tidak ada stage, commit, push, branch, worktree atau PR |
| Eksekusi | Git read/fetch, versi SDK, pembacaan source dan metadata resmi package. Tidak install, resolve dependency, run aplikasi, build, test, E2E, migration, seed, deployment atau koneksi database |

Baseline QA **historis**, bukan hasil tes R0: 1.040 Flutter, 679 unit + 7 tooling + 387 integration backend, 13 kelompok runner E2E, analyze/Web/APK dan CI sukses. Runner 13 kelompok mencakup satu kelompok provisioning appointment Backend Integration; tidak semuanya assertion browser. Laporan cleanup tetap mencatat latency snapshot yang pernah gagal dan pengecualian sesi development 124→125 yang disetujui pengguna; R0 tidak mengakses atau menilai ulang database tersebut. Lihat [audit cleanup](POST_MIGRATION_CLEANUP_AUDIT.md).

Dokumentasi acuan yang diperiksa pada bagian relevan: [AGENTS](../../AGENTS.md), [panduan UI QueueB](QUEUEB_UI_UX_GUIDELINES.md), [kontrak API](../backend/API_INTEGRATION_GUIDE.md), [ADMIN 2E](ADMIN_STATE_MANAGEMENT_STAGE2E.md), [PASIEN 3](PATIENT_STATE_MANAGEMENT_STAGE3.md), [PETUGAS 4](STAFF_STATE_MANAGEMENT_STAGE4.md), [PUBLIC DISPLAY 5](PUBLIC_DISPLAY_STATE_MANAGEMENT_STAGE5.md), [cleanup](POST_MIGRATION_CLEANUP_AUDIT.md), dan [Final E2E QA](../qa/FINAL_E2E_QA.md). Klaim historis seperti keberadaan SnapshotLoader pada dokumen tahap 5 tidak menggantikan source setelah cleanup.

## B. Environment Compatibility

### B1. Environment aktual dan package yang direkomendasikan

| Item | Temuan |
|---|---|
| Flutter aktual, hasil `flutter --version --no-version-check` | **3.47.5 stable**, framework revision `6a19cca564` |
| Dart aktual, hasil `dart --version` | **3.13.4 stable**, windows_x64 |
| Constraint aplikasi | `sdk: ^3.13.4`; lockfile `>=3.13.4 <4.0.0`, Flutter `>=3.47.0` |
| go_router existing | **Tidak ada** pada pubspec/lockfile/import produksi |
| Rekomendasi awal R1 | **Pin `go_router: 18.1.1`** saat implementasi disetujui; bukan memasang versi tak terverifikasi atau menjalankan pub upgrade |
| Metadata resmi 18.1.1 | Published `2026-10-20T15:50:56.65127Z`; Dart `^3.12.0`, Flutter `>=3.44.0` |
| Upgrade Flutter | **Tidak diperlukan berdasarkan constraint SDK yang diperiksa**. Keberhasilan solver/typecheck/build belum dibuktikan pada R0 |
| Web | `web/index.html:17` memakai `$FLUTTER_BASE_HREF`; tidak ditemukan pemilihan PathUrlStrategy |
| Android | Entry Activity Flutter, intent filter MAIN/LAUNCHER; tidak ditemukan VIEW/app-link/custom scheme pada manifest proyek. AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0 tetap |
| CI | Stable Flutter; pub get/format/analyze/test dan backend checks. CI baseline tidak membuktikan package yang belum dipasang |

Source: [pubspec:29](../../apps/client/pubspec.yaml#L29), [lockfile](../../apps/client/pubspec.lock), [web index:17](../../apps/client/web/index.html#L17), [Android manifest](../../apps/client/android/app/src/main/AndroidManifest.xml), [CI](../../.github/workflows/ci.yml).

Metadata diambil read-only dari [API versi resmi](https://pub.dev/api/packages/go_router/versions/18.1.1) dan dicocokkan dengan [halaman package](https://pub.dev/packages/go_router). Pemilihan 18.1.1 juga mempertimbangkan perbaikan collision key shell dan observer branch pada [changelog](https://pub.dev/packages/go_router/changelog), bukan hanya label latest. Metadata package tidak setara dengan hasil dependency resolution aplikasi.

### B2. Dependency dan ketersediaan API

Dependencies go_router 18.1.1: Flutter SDK, flutter_web_plugins SDK, collection `^1.15.0`, logging `^1.0.0`, meta `^1.7.0`, **material_ui `^1.0.0` dan cupertino_ui `^1.0.0`**. Dua package UI tersebut belum ada di lockfile aplikasi. Metadata resmi versi 1.0.0 keduanya menerima Dart `^3.12.0`/Flutter `>=3.44.0`; material_ui menerima intl `^0.20.2`, collection `^1.19.1`, material_color_utilities `^0.13.0`, vector_math `^2.2.0`. Lock saat ini mempunyai intl 0.20.3, collection 1.19.1, material_color_utilities 0.13.0, vector_math 2.4.0; tidak terlihat benturan langsung pada constraint yang diperiksa. Kandidat ini **belum membuktikan seluruh graph dapat di-resolve**. R1 wajib meninjau diff lockfile, SDK-pinned dependencies dan integrasi tipe Material/Cupertino sesudah pub get.

Rujukan metadata: [material_ui 1.0.0](https://pub.dev/api/packages/material_ui/versions/1.0.0), [cupertino_ui 1.0.0](https://pub.dev/api/packages/cupertino_ui/versions/1.0.0).

[ShellRoute](https://pub.dev/documentation/go_router/latest/go_router/ShellRoute-class.html) menyediakan Navigator shell dan `parentNavigatorKey`. [StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html) menyediakan Navigator per branch dan constructor indexedStack. [GoRouter API](https://pub.dev/documentation/go_router/latest/go_router/GoRouter-class.html) menyediakan `redirect`, `refreshListenable`, root navigator key, error builder dan pengaturan initial location. Dokumentasi API latest yang dibaca mengidentifikasi versi 18.1.1 pada waktu audit; URL dokumentasi versi eksplisit tidak dapat diambil oleh browser tool, tetapi metadata versi eksplisit berhasil diperiksa. Verifikasi kembali API versi terpasang di R1.

Tidak memerlukan generator route, build_runner, navigation service global, atau upgrade BLoC untuk blueprint ini.

## C. Current Navigation Architecture

### C1. Entry point, root dan stack

1. [main.dart:12](../../apps/client/lib/main.dart#L12) menginisialisasi binding, timezone dan semantics, membuat AppConfig/QueueApi/SessionStore, memulai restore **tanpa await** pada baris 21, lalu `runApp` baris 22. Tidak ditemukan entry point produksi lain dalam `lib`.
2. [app.dart:23](../../apps/client/lib/src/app.dart#L23) membuat `MaterialApp`; `home: _Root` baris 48 menyuplai route `/` implisit. `routes` baris 42 hanya mendefinisikan `/display`.
3. [app.dart:100](../../apps/client/lib/src/app.dart#L100): session phase selain ready merender `_SessionGate`; ready tanpa user merender LoginPage. [Baris 194](../../apps/client/lib/src/app.dart#L194) memilih AdminPage, QueuePage, DoctorPage, atau PatientPage berdasarkan `api.user.peran`. Tidak terjadi push Dashboard setelah login; widget root berubah.
4. [app.dart:192](../../apps/client/lib/src/app.dart#L192) meng-key subtree berdasarkan ID akun. Perubahan tipe portal juga mengganti subtree. [api.dart:362](../../apps/client/lib/src/api.dart#L362) membatasi empat role yang dikenali; default cabang pasien bukan izin backend untuk role tak dikenal.
5. Profil non-tab menggunakan [app.dart:109](../../apps/client/lib/src/app.dart#L109): satu call site `push(MaterialPageRoute(...UserProfilePage))`, dipakai header/footer lintas role. Route anonim ini tidak memberikan URL profil yang dapat dipulihkan sendiri.
6. Ada dua pemanggil `/display`: login pada [app.dart:105](../../apps/client/lib/src/app.dart#L105), dan callback pasien baris 204. Callback yang disediakan tidak otomatis berarti tombol tersebut sedang dirender oleh semua varian UI.
7. Tidak ada observer navigasi proyek, router delegate/parser, custom route information provider, route restoration registry, atau nested Navigator yang dikonstruksi source proyek.

`WidgetsApp` SDK saat ini mengaktifkan `reportsRouteUpdateToEngine` pada Navigator default. Jadi named route `/display` dapat dilaporkan ke engine/browser; **tidak benar menyebut semua Navigator 1.0 sama sekali tidak menyentuh URL**. Namun pergantian menu/tab lokal tidak memiliki RouteSettings sendiri. Perilaku framework initial route yang tidak dikenal berakhir pada fallback `/`; aplikasi tidak menyediakan layar not-found/unauthorized khusus. Ini temuan source SDK (`widgets/app.dart:1695–1711`, `widgets/navigator.dart:3017–3083` pada revision SDK di B), bukan hasil menjalankan browser R0.

### C2. State navigasi lokal dan lifecycle

| Pemilik | State navigasi yang ditemukan | Konsekuensi |
|---|---|---|
| `_LoginPageState` | `register` [app.dart:303](../../apps/client/lib/src/app.dart#L303), toggle baris 564 | Login/registrasi dua mode form pada root, bukan dua route |
| `_AdminPageState` | `selected=-1`, `staffTab=0` [admin.dart:48](../../apps/client/lib/src/admin.dart#L48); `selectResource` baris 397 | Sidebar mengubah index, feedback dan load; browser tidak tahu modul |
| `_PatientPageState` | `tab`, `reservationCreating`, `doctorDetail`, `bookingStage`, reservation mode/version [patient.dart:58](../../apps/client/lib/src/patient.dart#L58) | Booking/back internal memakai flags; bukan route stack |
| `_PatientHomeTabsState` | TabController [patient_home_v6.dart:224](../../apps/client/lib/src/patient_home_v6.dart#L224) | Mode/swipe Home V6 tetap state presentasi, bukan tab portal tambahan |
| `_UserProfilePageState` | `selected` dan empat panel [user_profile.dart:153](../../apps/client/lib/src/user_profile.dart#L153) | Informasi pribadi/foto/keamanan/role merupakan panel satu halaman |
| `_DisplayPageState` | Mode `legacy`, device phases dan monitor conditional [display.dart:61](../../apps/client/lib/src/display.dart#L61) | Pairing/monitor/reject bukan URL terpisah |

Filter tanggal dokter, pilihan ruang petugas, pagination, search, expiry timer dan fullscreen bukan route baru. Jangan memindahkan seluruh field tersebut ke router.

### C3. Metrik aktual dan metode

Scope scan: **106 file Dart produksi dalam `apps/client/lib`**, ditambah test/platform/config yang disebut. Pencarian keyword diikuti pembacaan constructor, callback, init/dispose dan caller. Hitungan adalah **call site statis**, bukan jumlah instance atau jumlah test yang diekspansi loop.

| Metrik | Hasil aktual | Definisi/metode |
|---|---:|---|
| Entry point Flutter produksi | 1 | `lib/main.dart:12`, satu runApp |
| MaterialApp / MaterialApp.router | 1 / 0 | Deklarasi aplikasi aktif |
| Lokasi bernama yang didukung | 2 | `/` implisit + `/display` eksplisit; **bukan** 21 URL |
| Pilihan utama lima portal | 17 | 9 ADMIN + 5 PASIEN + 1 PETUGAS + 1 DOKTER + 1 host DISPLAY |
| Inventaris tujuan/mode utama D | 21 | 17 di atas + login + register + session gate + profil lintas role yang dipush. Profil pasien tab sudah termasuk 5; satu entry tambahan mewakili akses profil non-tab |
| Aksi Navigator imperative | 50 | 40 pop, 3 push, 2 pushNamed, 2 popUntil, 3 removeRoute. Mencakup alias `navigator` dan `route.navigator?`, bukan hanya pencarian `Navigator.` |
| Factory modal | 26 | 15 showDialog, 2 showModalBottomSheet, 6 showDatePicker, 3 showTimePicker |
| Konstruksi DialogRoute tambahan | 2 | Scanner dan detail petugas, `queue.dart:88/176`; dua deklarasi field bertipe DialogRoute tidak dihitung sebagai konstruksi |
| Call site pembukaan overlay total | 28 | 26 factory + 2 konstruksi; satu factory CRUD/generic confirmation dapat melayani beberapa flow, bukan 28 halaman unik |
| PopScope / WillPopScope | 10 / 0 | Call site produksi |
| Pemilik state navigasi lokal utama | 6 | Kelas pada C2; tidak menghitung filter/layout sebagai destination |
| ShellRoute / StatefulShellRoute / nested Navigator proyek | 0 / 0 / 0 | Ada chrome sidebar/bottom bar, tetapi belum berupa router shells |
| BlocProvider / MultiBlocProvider | 21 / 3 | 20 `.value` + satu `create` DoctorPage; bukan 21 owner baru per navigasi |
| Provider yang didefinisikan oleh deklarasi route | 0 | Ownership sekarang berada pada widget/feature; tujuh host utama dibahas F3 |
| Guard routing utama | 3 kondisi | User session gate `app.dart:100`, role switch `:194`, device/monitor state gate `display.dart`; ini bukan tiga backend authorization guard |
| Listener yang langsung memengaruhi penutupan stack/modal | 4 | Root session, ADMIN activation scope, patient ticket consumer, staff queue consumer; daftar E2 |
| Browser URL handler custom | 0 | Tidak ada Uri.base, history.pushState/replaceState, popstate/hashchange atau URL strategy custom dalam source proyek |
| Android app/custom deep-link intent | 0 | Manifest proyek hanya MAIN/LAUNCHER; bukan klaim URL named route framework tidak ada |
| File test dengan simbol/harness navigasi | 27 | `*_test.dart` yang memuat Navigator/handlePopRoute/pageBack/PatientBottomNavigation/AdminNavigation/QueueBApp/LoginPage/UserProfilePage. Ini indeks kandidat, bukan jumlah tes navigasi runtime |
| Deklarasi tes terkait navigasi yang dipetakan eksplisit | 17 | Daftar I1; loop parameterized dihitung satu declaration site, bukan test-case total |

Count Navigator diverifikasi berdasarkan aksi, bukan `Navigator.of` sebagai operasi terpisah. Overlay route dapat dibuka dari helper reusable; tidak menjumlahkan inventory tujuan dengan factory modal. File test display/BLoC tanpa simbol navigasi tetap masuk strategi tes I, meskipun tidak termasuk indeks 27 file.

## D. Five-Portal Navigation Inventory — Existing

Semua path source di tabel relatif root repo. Kolom URL adalah **lokasi sekarang**, bukan usulan. `/` berarti root named location, biasanya pathname Web dengan hash/default engine; perpindahan lokal tidak menambahkan segmen. Profil/dialog anonim tidak memiliki identitas URL tersendiri. Dari `/display`, location bernama berbeda; state pairing/monitor tetap memakai location yang sama.

### D1. Auth dan profil lintas role

| ID/portal | Source & entry point | Current navigation | Current URL | Auth type | State owner | Risiko |
|---|---|---|---|---|---|---|
| A01 Login | `app.dart:101`, LoginPage | Conditional root | `/` | Belum login | QueueApi + local form | Flash/loop jika router mendahului restore |
| A02 Registrasi | `app.dart:303,564`, toggle form | Local bool; sukses kembali mode login `:315` | `/`, tanpa `/register` | Publik, hasil USER | LoginPage/QueueApi | History URL tidak merepresentasikan mode |
| A03 Session restore/error/sign-out gate | `app.dart:215`, `_SessionGate` | Conditional page, retry restore/logout | `/`, bukan route sesi | Account bootstrap | QueueApi.SessionPhase | Offline/storage error tidak boleh dianggap logout biasa |
| A04 Profil lintas role | `app.dart:109`, UserProfilePage | MaterialPageRoute anonim dari ADMIN/PETUGAS/DOKTER; USER memakai tab | Tidak ada URL profil | Akun valid | AccountProfileCubit milik halaman | Route anonim tertinggal saat logout; root/branch key salah |

Tidak ditemukan flow forgot/reset-password publik atau route access-denied khusus. **Ubah password milik sendiri** ada di panel profil melalui endpoint existing, lalu clear session; itu bukan reset-password deep link. Penolakan API umumnya menjadi feedback/error feature, bukan navigasi `/unauthorized`.

### D2. ADMIN — sembilan modul

| ID/modul | Source & entry point | Current navigation | Current URL | Auth | State owner | Risiko |
|---|---|---|---|---|---|---|
| M01 Dashboard | `admin.dart:480–500`, selected -1 | Sidebar/dashboard callback → selectResource | `/` | ADMIN | AdminCatalogRepository, proyeksi dashboard | Recreate katalog saat pindah URL |
| M02 Poliklinik | `admin_schema.dart:56`, selected 0 | Local selected + CRUD modal | `/` | ADMIN | PolyclinicCubit | Kehilangan state/error/command saat section berganti |
| M03 Dokter | `admin_schema.dart:89`, selected 1 | Local selected; editor, akun, hubungan poli, panduan berupa dialog | `/` | ADMIN | DoctorCatalogCubit + adapter editor | Dialog di root perlu scope sesi |
| M04 Ruang & loket | `admin_schema.dart:101`, selected 2 | Local selected + editor | `/` | ADMIN | RoomCubit | Salah mapping resource/index |
| M05 Jam & kapasitas poli | `admin_schema.dart:120`, selected 3 | List/group + single/bulk editor | `/` | ADMIN | ServiceScheduleCubit | Draft/batch terputus dan hasil tak pasti |
| M06 Jadwal praktik | `admin_schema.dart:138`, selected 4 | Agenda/list + PracticeScheduleEditor | `/` | ADMIN | PracticeScheduleCubit | Filter tanggal/editor dan callback save kehilangan owner |
| M07 Slot konsultasi | `admin_schema.dart:154`, selected 5 | Expand session dan slot editor | `/` | ADMIN | SlotSessionCubit per session, cache `admin.dart:58` | Eager fetch/double Cubit atau scope session tertukar |
| M08 Penugasan petugas | `admin_schema.dart:171`, selected 6 | Tab lokal Akun Petugas / Penugasan Loket `admin.dart:540` | `/` | ADMIN | StaffAccountCubit + AssignmentCubit | Tab reset; daftar akun/katalog ganda |
| M09 Manajemen Display | `admin.dart:480`, selected 7 | AdminDisplayPage + modal device/code | `/` | ADMIN, bukan device auth | DisplayManagementCubit | Kode aktivasi tertinggal; tertukar dengan kiosk scope |

`AdminPage` membuat repository/Cubit pada [admin.dart:101](../../apps/client/lib/src/admin.dart#L101), menyediakan `.value` pada baris 434, menutup miliknya pada baris 142. `selectResource` mengubah index/feedback dan memuat data (`:397`). Sidebar sempit merupakan modal bottom sheet (`:407`), bukan route modul. Back sistem menutup modal/route teratas atau root; tidak ada stack sembilan modul. Shared katalog dan Cubit tetap hidup ketika modul berganti, tetapi child dengan `ValueKey(resource.path)` (`:580`) dapat di-unmount; jangan menjanjikan semua filter/form lokal sudah persistent.

### D3. PASIEN — lima navigasi bawah

| ID/tab | Source & entry point | Current navigation | Current URL | Auth | State owner | Risiko |
|---|---|---|---|---|---|---|
| P01 Beranda | `patient.dart:1010`, tab 0 | Conditional `_home`, Home V6 mode/swipe | `/` | USER | PatientOverviewCubit + Home state | Mode/search/scroll reset saat shell berubah |
| P02 Reservasi | `patient.dart:966–1007`, tab 2 | ReservationList atau inline create flow | `/` | USER | PatientReservationsCubit + PatientBookingCubit | URL tidak tahu list/draft/doctor/slot |
| P03 Tiket Saya | `patient.dart:1012,1452`, tab 1 | Conditional list; openTicket modal | `/` | USER | Shared repository/reservations; dialog TicketCubit | Recreate feed, replay penerbitan QR |
| P04 Janji Temu | `patient.dart:1014`, tab 3 | PatientAgenda; ticket callback | `/` | USER | Shared reservations snapshot | Appointment.id tertukar dengan tiket.id |
| P05 Profil | `patient.dart:1048`, tab 5 | Lazy profileVisited lalu retained child | `/` | USER | AccountProfileCubit dalam UserProfilePage | State akun A bertahan untuk akun B |

Mapping bottom index → internal tab adalah **`[0,2,1,3,5]`** ([patient.dart:966](../../apps/client/lib/src/patient.dart#L966)). `IndexedStack` pada baris 985 hanya mempunyai **tiga slot**: ReservationList, satu slot konten yang berganti Home/tiket/agenda/booking/history, dan profil lazy. Tidak ada lima Navigator, tidak ada stack independen per tab, dan retention profil tidak berarti seluruh subtree setiap tab dipertahankan identik.

`PatientPage` membuat satu PatientRepository dan tiga Cubit (`patient.dart:195`), membagikan tiga provider `.value` (`:916`) dan menutup owner pada `:355`; semua konsumen menggunakan PatientUpdates yang sama. Booking memiliki flags UI di parent dan state pilihan/command pada Cubit. Mengganti tab saat busy dicegah tombol (`:967`), tetapi browser URL nantinya menjadi jalur masuk/keluar tambahan yang perlu guard.

### D4. PETUGAS, DOKTER dan PUBLIC DISPLAY

| ID/portal | Source & entry point | Current navigation | Current URL | Auth type | State owner | Risiko |
|---|---|---|---|---|---|---|
| S01 PETUGAS dashboard | `app.dart:196`, `queue.dart:33` | Conditional portal; ruang dari assignment/BLoC | `/` | JWT PETUGAS + izin ruang backend | StaffQueueBloc / StaffQueueRepository | Route change membuka feed kedua atau mereset command lock |
| D01 DOKTER dashboard | `app.dart:200`, `doctor.dart:19` | Satu dashboard; tanggal/filter/detail pendukung | `/` | JWT DOKTER + profil aktif backend | DoctorPortalCubit / ApiDoctorRepository | Cubit ditutup saat profil dibuka; data lama saat role berubah |
| V01 PUBLIC DISPLAY host | `app.dart:43`, `display.dart:42` | pushNamed `/display`, conditional activation/monitor/reject | `/display` | Cookie/header token perangkat, **bukan JWT akun** | DisplayDeviceCubit + DisplayMonitorBloc + audio/controller | Root account popUntil, recreate owner, tab selector dan audio replay |

### D5. Tujuan/flow pendukung, overlay dan panel existing

Ini **tidak menambah URL existing** pada D1–D4. Reusable factory dapat melayani beberapa konteks.

| Flow | Source aktual | Bentuk dan owner/Back sekarang | Perlakuan blueprint |
|---|---|---|---|
| ADMIN create/edit generik, bulk jam, praktik, dokter | `admin.dart:213–252` | Satu showDialog memilih editor; beberapa editor PopScope busy | Tetap modal; tidak semua CRUD dijadikan URL |
| ADMIN akun dokter / relasi poli / panduan | `admin.dart:371,518,591`, `doctor_account.dart:76` | Dialog terpisah; callback rekonsiliasi parent | Pertahankan otorisasi dan hasil dialog |
| ADMIN delete/deactivate | `admin_delete.dart:16`, `widgets.dart:114` | Dialog reusable, typed result/konfirmasi | Tetap overlay; jangan replay action dari URL |
| ADMIN device editor / activation / rename | `admin_display.dart:59,80,147,475` | Dialog, transient code dibersihkan saat expiry/sesi/dispose | Root modal di scope ADMIN, bukan kiosk navigator |
| Pemilih tanggal/jam | `admin.dart:795,815`, `admin_practice_form.dart:155,174`, `admin_schedules.dart:444`, `admin_practice_agenda.dart:80`, `patient.dart:1266,1363`, `doctor.dart:42` | Native Flutter picker overlay | Tetap overlay; validasi kalender pelayanan dipertahankan |
| Pilih cara reservasi | `patient_reservations.dart:490`, dipanggil `patient.dart:421` | Bottom sheet; hasil memilih legacy/nearest flow | Tetap transient; URL create hanya menyimpan enum pilihan aman |
| Ambil antrean/booking dan detail dokter pasien | `patient.dart:175,366,389,421,448,1092,1163` | Inline state, bukan push halaman; navigasi Back UI mengubah flags | List/new/doctor dapat dipetakan ke route yang bisa hydrate |
| Konfirmasi booking dan pembatalan appointment | `patient.dart:255,294` | Dialog; validasi pilihan sebelum POST | Tetap dialog, tidak ada URL confirm/POST |
| Detail reservasi/tiket + QR | `patient.dart:331,1512,1544` | Satu `_TicketDialog`, TicketCubit per dialog, timer/QR transient | Tiket deep link opsional terdefinisi F; QR tetap explicit action |
| Riwayat kunjungan | `patient.dart:1414`, conditional `:1045` | Data historis ada dalam proyeksi tiket/reservasi. Branch `_history` mensyaratkan tab 4, tetapi tidak ditemukan assignment tab=4 dari UI aktif | **Tidak menghitung tab 4 sebagai halaman navigasi aktif**; jangan menciptakan route history dalam R2 tanpa keputusan fitur |
| PETUGAS QR scanner | `queue.dart:86`, `staff_qr_scanner.dart:71` | Root DialogRoute, PopScope `!processing`; lifecycle stop/start dan dispose kamera | Tetap root modal, tidak membuat scanner branch offstage |
| PETUGAS detail baris antrean | `queue.dart:173` | Root DialogRoute read-only, ditutup pada scope ruang/tanggal/sesi berubah | Tetap dialog, tidak perlu URL dengan identitas pasien |
| PETUGAS command | `queue.dart:69` | Method BLoC, bukan halaman/route baru | CALL/RECALL/dll bukan destinations |
| Detail antrean DOKTER | `doctor_dashboard.dart:575` | showDialog read-only dari row; file ini memiliki perubahan lokal terlindungi | Tetap modal; jangan membuat halaman klinis/command dokter |
| Profil profesional DOKTER | `user_profile.dart:585` | Informasi profesional di profil akun. `DoctorProfessionalDialog` di `doctor_professional.dart:157` tidak ditemukan mempunyai caller produksi | Jangan menghitung class tanpa caller sebagai route aktif atau menambahkan route baru untuknya |
| PUBLIC DISPLAY activation / konfigurasi token manual | `display.dart:94,101,238,279` | Form dalam host; toggle legacy, input ID layanan/token sementara | Pertahankan satu host; input secret tidak menjadi parameter URL |
| PUBLIC DISPLAY monitor/reject/ganti perangkat | `display.dart:62–80,162`, `DisplayDeviceCubit` | State capability tervalidasi; disconnect/restore, bukan push screen | Device auth tetap di feature, bukan redirect akun |
| Fullscreen dan pagination display | `display.dart:188`, `display_fullscreen_web.dart:32`, `display_board.dart:477,741` | Browser API + visual timer 12 detik, bukan navigasi | Tidak mengubah route/page key atau membuat feed baru |

Tidak ditemukan halaman pemilihan **API base** runtime. AppConfig menentukan API base lewat dart-define, dan selector display di-key berdasarkan base itu. Pemilihan perangkat/kode bukan pemilihan server bebas.

## E. Authentication & Session Routing

### E1. Kontrak sesi yang harus tetap

- QueueApi adalah ChangeNotifier kanonis, memegang phase `ready/restoring/offline/storageError/signingOut` ([api.dart:11](../../apps/client/lib/src/api.dart#L11)). Router tidak menyimpan token atau menentukan role dari decode JWT sendiri.
- Login menerima token pair lalu memvalidasi `/auth/me` sebelum menerbitkan user ([api.dart:255](../../apps/client/lib/src/api.dart#L255)). Restore serial/single-flight menguji stored pair dan identitas server (`:299`). Tidak ada cached role yang membuka portal sebelum validasi.
- AndroidSessionStore memakai secure storage dan namespace per API base; Web/unsupported memakai MemorySessionStore ([session_store.dart:101](../../apps/client/lib/src/session_store.dart#L101)). Refresh Web pada protected URL memerlukan login lagi; deep link tetap dapat menjadi tujuan sesudah login yang benar.
- Access 401 dapat memicu refresh single-flight dan retry hanya setelah guard rejection ([api.dart:85](../../apps/client/lib/src/api.dart#L85), `:464`), bukan retry timeout/domain POST. Offline/5xx/storage error menahan sesi dan menyediakan recovery; jangan menghapusnya melalui redirect login yang menyamakan semua error.
- Logout membersihkan lokal lebih dahulu, menginvalidasi generation, menunggu rotasi pending untuk pencabutan yang benar, lalu kembali ready tanpa user ([api.dart:520](../../apps/client/lib/src/api.dart#L520)). Change password profil memakai clear session, bukan reset-password URL.
- Role efektif backend berasal dari pengguna/sesi DB terbaru, dengan pemeriksaan profil DOKTER aktif ([jwt.strategy.ts:24](../../apps/api/src/auth/jwt.strategy.ts#L24)); redirect UI bukan otorisasi domain.
- AccountProfileCubit hanya proyeksi profil/status; owner tetap QueueApi. Repository profil mengikat identitas/role ([account_profile_repository.dart:16](../../apps/client/lib/src/features/account/data/account_profile_repository.dart#L16)), dan halaman mengosongkan UI ketika owner berakhir (`user_profile.dart:654`).

### E2. Listener/closure yang penting

| Lokasi | Perilaku sekarang | Implikasi migrasi |
|---|---|---|
| `app.dart:63–75` | Listener QueueApi menjadwalkan post-frame popUntil root ketika user/phase tidak valid; mounted diperiksa | Harus digantikan oleh satu pemilik redirect. Secara source, closure dapat mem-pop `/display` di atas root ketika sesi akun berubah, walaupun device request `authenticated:false`; ini risiko collision yang perlu tes eksplisit |
| `admin_display.dart:483,497–512` | Listener sesi dan timer expiry membersihkan activation dan pop/remove dialog | Tetap membersihkan secret, tetapi removeRoute hanya untuk dialog imperative yang benar-benar dimiliki, bukan router-managed Page sembarang |
| `patient.dart:1619–1633` | TicketCubit sessionEnded menutup/menghapus ticket modal | QR/timer tetap dibersihkan; bentuk Page deklaratif kelak harus dikeluarkan melalui router, bukan dua mekanisme yang berlomba |
| `queue.dart:162–168` | Consumer pada ended/ruang/tanggal berubah menutup dialog melalui route reference; dispose juga membersihkan | Root navigator key/owned dialog reference tetap benar setelah nested navigator diperkenalkan |

Pemeriksaan mounted/generation/ownership ditemukan pada jalur utama; bukan bukti tidak mungkin ada race runtime. Router refresh dan legacy post-frame popUntil yang aktif bersamaan berisiko navigasi ganda. Perubahan profile/token yang bukan pergantian scope tidak boleh me-reset router.

### E3. Redirect proposal — bukan implementasi existing

Gunakan adapter `Listenable` dari **QueueApi existing**, memfilter perubahan `(phase, user.id, user.peran)` dan mencatat epoch lifecycle saat scope akun berakhir/berganti. Counter epoch hanya identitas lifecycle turunan, **bukan auth state manager kedua**. Login/restore/refresh tetap dilakukan QueueApi di luar redirect. Keputusan redirect dibuat dari snapshot saat ini tanpa HTTP tambahan atau await login di callback.

Urutan prioritas:

1. Cocokkan **route display yang terdaftar secara tepat**, bukan `startsWith('/display')` yang menerima path palsu; bebaskan `/display` dari guard akun, termasuk ketika akun restoring/offline/logout.
2. Klasifikasikan unknown/invalid path ke error UI aman; jangan mencetak raw URL/exception atau memaksakan role dari prefix yang tidak dikenal.
3. Untuk scope akun, phase non-ready → session gate; ready tanpa user → login; validasi role exact whitelist → portal sesuai role. Role mismatch → forbidden, bukan menampilkan portal tujuan sekejap.
4. Pada phase ready yang terverifikasi, login/register/session dapat dialihkan ke safe return target yang cocok role atau default role home. Jangan redirect lokasi yang sudah benar kembali ke dirinya sendiri.

| Kondisi | Keputusan proposal |
|---|---|
| Belum login, membuka halaman protected | `/login?from=<lokasi-internal-aman>`; tidak me-render child protected |
| Startup restoring / signingOut | `/session`, simpan tujuan aman; tidak membuat Cubit portal baru |
| Offline / storageError | Session recovery UI existing, tetap retry/logout; tidak membuang credential karena redirect |
| Login sukses | QueueApi menerbitkan identitas; satu refresh router ke tujuan yang cocok role/default home |
| Login gagal | Tetap login, tampilkan error lokal, tidak consume return target |
| Logout / invalid session / password change | Evict seluruh scope akun/overlay sensitif, login/session gate sesuai phase; jangan memulihkan protected stack dengan Back |
| Role berubah | Evict scope lama, scope baru di-key role+epoch; forbidden/home sesuai target, bukan cache JWT role |
| USER mencoba ADMIN | Forbidden dengan tautan home USER; backend tetap menolak request di luar izin |
| Login/register dibuka saat authenticated | Kembali ke role home atau safe target; cegah login↔home loop |
| Cold protected URL pada Web | Tahan URI melalui login memory-session; buka target hanya sesudah `/auth/me` sah |
| Device expired/revoked/uncertain | Feature display menolak/memulihkan scope di `/display`; **tidak** menuju login akun |
| Unknown route / malformed UUID/query | Error builder aman, aksi ke login/home yang sah; tidak membuka halaman palsu atau mengirim mutasi |

Default role home: ADMIN `/admin`, USER `/patient`, PETUGAS `/staff`, DOKTER `/doctor`. `/display` tetap jalur perangkat independen.

**Safe return policy:** terima hanya URI relatif internal yang cocok registry dan role, tanpa scheme/authority/userInfo, tanpa path `//`, backslash, dot traversal atau nested return chain. Parse/normalisasi sekali dengan Uri, whitelist query dan parameter, lalu revalidate setelah login. Tolak absolute URL, encoded traversal, unknown target, login/session loop dan parameter secret. Jangan persist return target di secure storage sebagai sesi baru. Gunakan query `from` yang disanitasi atau state transient router; jangan mengandalkan `extra` agar cold refresh dapat dipulihkan. Jangan memasukkan `from` ke `from` berulang kali.

[Dokumentasi redirect resmi](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html) menjadi acuan mekanisme; aturan scope pada tabel di atas diturunkan dari kontrak QueueB. `refreshListenable` dipasang/dilepas satu kali. Jangan memaksa `initialLocation` menimpa platform deep link; root `/` cukup mengarahkan berdasarkan kondisi, dengan platform default location tetap dihormati.

## F. Proposed go_router Architecture

**Seluruh path di bagian ini adalah usulan R1–R3, belum tersedia dalam aplikasi.** Dengan strategi hash, path `/admin` secara browser menjadi misalnya `http://host/#/admin`; bagian hash bukan secret store.

### F1. Route tree rekomendasi

```text
GoRouter tunggal — root navigator key stabil
├── /                            entry / default role redirect
├── /login                       form login
├── /register                    form registrasi existing
├── /session                     recovery / restoring / sign-out gate existing
├── /forbidden                   feedback akses, tanpa data protected
│
├── ADMIN ShellRoute — AdminPortalScope per akun/role/epoch
│   └── /admin                   Dashboard
│       ├── /admin/polyclinics
│       ├── /admin/doctors
│       ├── /admin/rooms
│       ├── /admin/service-hours
│       ├── /admin/practice-schedules
│       ├── /admin/consultation-slots
│       ├── /admin/staff-assignments
│       ├── /admin/displays
│       └── /admin/profile       shared profile widget, root presentation
│
├── PASIEN StatefulShellRoute.indexedStack — PatientPortalScope sekali
│   ├── branch Home: /patient
│   ├── branch Reservasi: /patient/reservations
│   │   ├── /patient/reservations/new
│   │   └── /patient/reservations/doctors/:doctorId
│   ├── branch Tiket: /patient/tickets
│   │   └── /patient/tickets/:ticketId
│   ├── branch Janji Temu: /patient/appointments
│   └── branch Profil: /patient/profile
│
├── /staff                       QueuePage owner stabil
│   └── /staff/profile           shared profile widget di atas parent
├── /doctor                      DoctorPortalCubit owner stabil
│   └── /doctor/profile          shared profile widget di atas parent
└── /display                     satu DisplayPage; device lifecycle internal
    (pair/restore/reject/monitor/fullscreen bukan route tambahan)

Unknown location → errorBuilder, bukan route wildcard berisi raw URL.
Konfirmasi, QR, scanner, picker dan activation tetap overlay transient.
```

Tree mengandung **28 GoRoute location yang diusulkan**, tidak termasuk shell tanpa path, error builder, dan overlay transient. Segmen penuh ditampilkan untuk keterbacaan; konfigurasi child nantinya memakai path relatif sesuai API go_router, bukan menempelkan slash penuh secara keliru.

### F2. Matriks route proposal

Aturan E3 berlaku untuk semua row. `U` = USER, `A` = ADMIN, `S` = PETUGAS, `D` = DOKTER. Nama route unik, tidak dipakai sebagai role/security token.

| Route name | Proposed path | Role/auth | Shell | Parameter aman | Owner | Redirect/entry rule |
|---|---|---|---|---|---|---|
| entry | `/` | Semua | Root | — | QueueApi | Session/login/default role home |
| login | `/login` | Publik | Root | safe `from` | Login form + QueueApi | Authenticated → safe home/target |
| register | `/register` | Publik | Root | — | Login form registration mode | USER registration existing; sukses login |
| session | `/session` | Bootstrap akun | Root | safe `from` | QueueApi | Phase ready → login/home/target |
| forbidden | `/forbidden` | Feedback aman | Root | — | Stateless presentation | Tidak memuat data target terlarang |
| admin-home | `/admin` | A | Admin | — | Shared catalog | Role A terverifikasi |
| admin-polyclinics | `/admin/polyclinics` | A | Admin | — | PolyclinicCubit | Role A |
| admin-doctors | `/admin/doctors` | A | Admin | — | DoctorCatalogCubit | Role A |
| admin-rooms | `/admin/rooms` | A | Admin | — | RoomCubit | Role A |
| admin-service-hours | `/admin/service-hours` | A | Admin | — | ServiceScheduleCubit | Role A |
| admin-practice | `/admin/practice-schedules` | A | Admin | — | PracticeScheduleCubit | Role A |
| admin-slots | `/admin/consultation-slots` | A | Admin | Opsional session UUID bila benar-benar dibutuhkan | SlotSessionCubit per sesi valid | Katalog hydrate sebelum expand; tanpa eager slot load |
| admin-staff | `/admin/staff-assignments` | A | Admin | Opsional `tab=accounts/assignments` | StaffAccount/AssignmentCubit | Enum whitelist; bukan UUID role |
| admin-displays | `/admin/displays` | A | Admin | — | DisplayManagementCubit | ADMIN scope, tanpa credential kiosk |
| admin-profile | `/admin/profile` | A | Root di atas Admin | — | AccountProfileCubit halaman | Role A, parent scope tidak diduplikasi |
| patient-home | `/patient` | U | Patient/Home | — | Shared overview/Home UI | Role U |
| patient-reservations | `/patient/reservations` | U | Patient/Reservasi | — | Shared reservations | Role U |
| patient-booking | `/patient/reservations/new` | U | Patient/Reservasi | Enum mode; opsional clinic UUID | Shared booking | GET validasi pilihan, tidak otomatis POST |
| patient-doctor | `/patient/reservations/doctors/:doctorId` | U | Patient/Reservasi | UUID dokter, opsional clinic UUID | Shared catalog/booking | Resolve relasi sah; stale/404 → feedback aman |
| patient-tickets | `/patient/tickets` | U | Patient/Tiket | — | Shared reservations | Role U |
| patient-ticket | `/patient/tickets/:ticketId` | U | Patient/Tiket | UUID tiket | PatientTicketCubit per ID | GET `/tiket/:id` own-user; QR tidak auto-issue dari cold link |
| patient-appointments | `/patient/appointments` | U | Patient/Agenda | Opsional tanggal valid | Shared reservations | Role U; tanggal timezone pelayanan |
| patient-profile | `/patient/profile` | U | Patient/Profil | — | ProfileCubit lazy branch | Role U, tidak membuat profil kedua |
| staff-home | `/staff` | S | Tidak perlu shell | — | StaffQueueBloc | Role S; assignment di feature/backend |
| staff-profile | `/staff/profile` | S | Root child | — | ProfileCubit halaman | Role S, Back mengembalikan parent aman |
| doctor-home | `/doctor` | D | Tidak perlu shell | Opsional tanggal valid | DoctorPortalCubit | Role D; dokter efektif dari backend |
| doctor-profile | `/doctor/profile` | D | Root child | — | ProfileCubit halaman | Role D |
| display | `/display` | Perangkat, bukan akun | Root device host | **Tidak ada token/device credential/API base query** | DeviceCubit + MonitorBloc + audio | Guard akun dilewati tepat untuk route ini; feature memvalidasi perangkat |

Tidak mengusulkan route forgot/reset password, detail klinis dokter, endpoint reservasi baru, atau `/patient/history` untuk branch tidak aktif. Detail reservasi/appointment yang existing hanya membuka tiket dapat tetap memakai dialog tersebut; jangan memakai appointment.id sebagai ticketId.

Parameter ID bukan otorisasi dan tetap dapat menjadi metadata sensitif dalam history; masukkan hanya jika diperlukan untuk hydrate. Jangan memasukkan nama/email pasien, JWT, password, raw QR, kode aktivasi, token pairing, atau endpoint server bebas dalam URL. Susun query dengan Uri, whitelist enum/tanggal/UUID, tangani encoded slash, null dan 404 secara eksplisit. `extra` boleh menjadi optimasi tampilan sementara, **bukan satu-satunya sumber data** atau authorization bypass.

### F3. Shell dan provider ownership

| Scope/host | Lifetime proposal | Hal yang harus dipertahankan |
|---|---|---|
| Application/router | Satu router dan refresh adapter per QueueBApp; QueueApi diinjeksi sekali | Tidak `GoRouter()` di build; adapter dispose tidak menutup API yang dimiliki pemanggil |
| AdminPortalScope | Melewati sembilan child route sampai scope akun berakhir | Satu catalog repository; Cubit master/staff/display, dynamic slot Cubit per sesi; shared state tidak diulang per module builder |
| PatientPortalScope | Di atas lima branch, keyed akun+role+epoch | Satu PatientRepository/PatientUpdates dan overview/booking/reservations Cubit; branch tidak membuka feed tambahan |
| Ticket detail host | Per ticketId aktif dalam scope pasien | TicketCubit ditutup tepat sekali, QR/expiry/countdown tetap transient; GET hydrate, bukan POST restore |
| QueuePage | Selama parent `/staff` termasuk ketika profile child berada di atasnya | Satu StaffQueueBloc/repository/command lock; ganti ruang melalui BLoC, bukan URL yang dipercaya mentah |
| DoctorPage | Selama parent `/doctor`, keyed identitas/epoch | Satu DoctorPortalCubit/repository; profil tidak membuat owner dokter kedua |
| UserProfilePage | Per halaman profil nonpasien; lazy retained pada branch profil pasien | AccountProfileCubit tetap metadata projection; password/preview dibersihkan pada logout/dispose |
| DisplayPage | Tepat satu host untuk location `/display` selama tab aktif | DeviceCubit/MonitorBloc/audio/fullscreen/clock dibuat sekali; phase/URL refresh tidak memanggil pair/legacy/restore berulang |

Tujuh host feature utama existing yang perlu dilacak: AdminPage, PatientPage, ticket dialog, QueuePage, DoctorPage, UserProfilePage, DisplayPage. Ini bukan klaim semua fallback editor mempunyai lifetime identik. Adapter/editor standalone existing tetap dipakai bila diperlukan; jangan memindahkan business state ke router.

ADMIN shell harus memisahkan ownership scope dari content modul secara terarah. Menaruh `AdminPage` lengkap pada setiap builder child akan membuat katalog/Cubit berulang dan tidak memenuhi blueprint. Selected menu menjadi **proyeksi location → section**, bukan index lokal kedua yang dapat berbeda dari URI. Search/filter/draft yang bukan location tetap lokal. Pertahankan semantik child state yang memang reset sekarang; tidak perlu IndexedStack sembilan modul atau eager load seluruh data.

PASIEN membutuhkan satu host provider bersama dan view/adapter per branch. **Jangan menaruh lima PatientPage lengkap di lima branch.** Branch yang belum dikunjungi tidak dipreload; profil tetap lazy. Stateful shell menambah Navigator/memori untuk branch yang sudah dikunjungi; lakukan pengukuran lifecycle/request sebelum menyimpulkan ada manfaat performa. `PatientHomeTabs` untuk mode Home tetap terpisah dari lima branch portal. Jangan mempertahankan IndexedStack tiga slot lama sebagai pemilik navigasi paralel permanen di dalam shell baru.

PETUGAS dan DOKTER tidak membutuhkan shell hanya untuk dashboard+profil; nested GoRoute sudah cukup. AccountProfile memakai root presentation key yang tepat; tidak memerlukan akses ke katalog ADMIN/monitor dokter untuk mengambil identitas akun.

### F4. Back, tab dan modal contract proposal

| Aksi | Keputusan yang diusulkan |
|---|---|
| Sidebar ADMIN | Navigate dengan `go` ke child URL; selected diturunkan dari location; browser history merekam perpindahan yang bermakna |
| Lima tab pasien | `goBranch` untuk branch yang dituju; state branch yang pernah dibuat dipertahankan tanpa membuka repository baru |
| Menekan Reservasi ketika flow create sedang terbuka | Pertahankan intent source: kembali ke list bila tidak busy (`reservationCreating=false` pada pemilihan tab). Jangan diam-diam memulihkan draft lalu mengirim POST |
| Android Back ketika modal/scanner terbuka | Tutup overlay teratas bila canPop; ketika processing/command guard aktif ikuti kontrak busy. Kamera/QR harus dispose/clear |
| Android Back pada detail/booking | Pop/declaratively return ke root branch, tanpa POST/replay; pilihan draft hanya sesuai kebijakan existing |
| Android Back pada root tab pasien selain Home | Kembali ke Home; root Home berikutnya mengikuti platform exit. Tidak memperkenalkan stack riwayat tab Android tambahan |
| Browser Back/Forward | Ikuti riwayat URL browser, bukan memaksakan aturan Back Android atau selected index lama |
| Cold deep link tanpa stack lokal | Parent declarative memberikan Back destination yang sah; aksi Back aplikasi punya fallback role home |
| Profil ADMIN/PETUGAS/DOKTER | Child route terdaftar, root navigator untuk overlay halaman; Back kembali ke parent, tidak ke portal akun lama |
| Revoke/logout/account switch | Auth/scope eviction menang atas guard draft/busy; jangan membiarkan onExit menahan UI private setelah izin hilang |
| Hard refresh/tab close saat POST pending | Tidak dapat dijamin tertahan oleh PopScope. Muat ulang tidak memutar POST; tampilkan/pakai rekonsiliasi status existing sesuai sesi |

[`go` membangun stack dari konfigurasi; dokumentasi juga memperingatkan keterbatasan imperative push terhadap browser history](https://pub.dev/documentation/go_router/latest/topics/Navigation-topic.html). Gunakan go/registered route untuk destinasi yang perlu URL. Navigator imperative tetap dapat dipertahankan untuk dialog, tetapi setiap pemanggil memakai root/branch navigator yang disengaja. Jangan menerapkan `removeRoute` lama pada Page deklaratif milik router. Tidak ditemukan WillPopScope untuk dimigrasikan, tetapi sepuluh PopScope dan jalur browser/Android tetap harus diuji, termasuk predictive Back yang didukung perangkat.

### F5. PUBLIC DISPLAY — keputusan keamanan khusus

Source utama: [display.dart:42](../../apps/client/lib/src/display.dart#L42), [device repository:45](../../apps/client/lib/src/features/display/data/display_device_repository.dart#L45), [selector Web:15](../../apps/client/lib/src/display_selection_web.dart#L15), [cookie backend:35](../../apps/api/src/display/display-cookie.ts#L35), [monitor rebase:156](../../apps/client/lib/src/features/display/application/display_monitor_bloc.dart#L156).

1. Scope perangkat dibentuk dari metadata session backend, deviceId/layananId/API base/epoch, bukan query location. Restore isolated tanpa selector mengembalikan null dan tidak mengambil cookie ambient (`repository:61–65`).
2. Pairing mengirim kode transient, `authenticated:false`, dan `isolasiSesi:true`; metadata diikuti penyimpanan selector lalu GET sesi yang harus cocok device/poli (`:68–96`). Router tidak melakukan POST pairing, refresh akun, atau pembacaan cookie.
3. Cookie **dibagi oleh browser sesuai host/path**, bukan per tab. Nama `queueb_display_<UUID>`, HttpOnly, SameSite Strict, host-only, Path `/`, dan selector tab mengarahkan cookie yang benar. SessionStorage per tab **tidak membuat cookie per tab**. Duplicate/opener dapat menyalin selector dan mula-mula mewakili perangkat sama. XSS same-origin, kuota/header cookie dan kebijakan browser tidak diselesaikan routing.
4. Semua device endpoint memakai transport tanpa auth akun; authenticated account yang kebetulan ada bukan syarat kiosk. Root redirect harus mengecualikan display sebelum pemeriksaan phase akun. Listener popUntil akun lama harus tidak lagi mengendalikan kiosk.
5. Pertahankan satu DisplayPage, bukan `/display/pair` dan `/display/monitor` dengan owner berbeda. State pairing/restoring/uncertain/rejected tetap internal. Parameter atau fullscreen tidak menjadi page key; jangan menumpuk dua DisplayPage dalam engine yang sama.
6. Revoke/rotate/401/403 membersihkan scope/monitor/audio melalui feature existing, bukan pergi ke `/login`. Kegagalan pairing tak pasti tidak diulang otomatis; storage fail tidak diselesaikan dengan menebak cookie/token.
7. Clock dan dua paginator visual 12 detik (`display_board.dart:477,741`) tidak memanggil navigasi. Rebuild router atau fullscreen tidak boleh me-reset pagination/voice atau membuka socket kedua.
8. Initial load, reconnect, resume dan manual refresh membentuk baseline TTS senyap; CALL/RECALL baru dideduplikasi lewat peristiwaId existing. Route visit/rebuild bukan trigger announcement.
9. Keluar halaman harus membuang owner UI/feed/audio secara benar, tetapi **bukan otomatis server forget**. Navigasi keluar dan aksi Putuskan/Ganti perangkat mempunyai makna berbeda; pertahankan cookie/selector restore sesuai tindakan existing.
10. API base tetap AppConfig compile-time. Tidak ada URL server picker pada source; menambah query `apiBase` akan menjadi fitur/risk baru di luar migrasi routing.

### F6. Web/deep link dan hosting

[Flutter Web memakai hash secara default](https://docs.flutter.dev/ui/navigation/url-strategies). Source proyek tidak memilih strategi lain. `web/index.html:17` memakai placeholder base-href. R1 mempertahankan hash untuk menghindari dependency baru pada rewrite hosting. Server QA [browser-smoke.cjs:57–66](../../apps/client/tool/browser-smoke.cjs#L57) hanya memetakan `/` ke index dan mengembalikan 404 untuk file/path yang tidak ada; **belum** mempunyai fallback nested path. Tidak ditemukan konfigurasi deployment Flutter terverifikasi yang membuktikan fallback production siap.

Jika PathUrlStrategy kelak disetujui, host harus mengembalikan index untuk route aplikasi yang sah, dengan base-href benar untuk subdirectory; static asset, REST `/api/v1`, dan WebSocket `/socket.io/` jangan ditelan fallback. R0 tidak mengubah hosting. Hash route pada `/#/patient/tickets/<uuid>` tetap memerlukan login Web sesudah refresh, GET tiket milik sendiri dan error handling bila ID tidak ada.

Skenario wajib R3: direct login, direct ADMIN, direct Reservasi, nested refresh, Back/Forward, copy/paste, unknown path, role salah, logout pada nested page, restore Android pada protected location, encoded/invalid query, dan cold ticket detail tanpa extra. Browser Back tidak boleh menghidupkan kembali scope yang sudah dicabut.

### F7. Struktur file proposal dan transisi

```text
apps/client/lib/src/routing/
  app_router.dart               registry, keys dan lifetime router
  route_policy.dart             role/public/device classification + safe return
  route_refresh_notifier.dart   adapter QueueApi, filtered notify + scope epoch
  route_names.dart              opsional jika constants lintas feature diperlukan
```

Scope adapter/host ADMIN/PASIEN ditempatkan dekat feature existing agar ownership init/dispose jelas, bukan service locator global. Pisahkan shell definitions hanya jika app_router menjadi sulit ditinjau. Tidak perlu file device router terpisah hanya untuk satu location, auth controller kedua, session store kedua atau generator.

Pada transisi, compatibility host dapat merender flow lama sambil link utama dipindahkan secara berurutan. Legacy dialog/picker boleh tetap memakai Navigator yang sama dengan root key. Legacy selected/tab dipakai sebagai adapter sementara dari location, **bukan source of truth permanen kedua**. Hapus dua owner navigasi root ketika redirect aktif; jangan membiarkan post-frame popUntil dan GoRouter mengubah stack bersamaan.

## G. Risk Matrix

Severity mengikuti dampak QueueB: P0 keamanan/scope/operasional kritis; P1 portal/auth/lifecycle utama; P2 Back/deep-link/state UX; P3 minor. Mitigasi berikut adalah pekerjaan R1–R3, belum diterapkan.

| ID | Severity | Risiko/bukti | Mitigasi blueprint | Tes wajib |
|---|---|---|---|---|
| R01 | P1 | Redirect login/home/session loop | Pure finite-state policy, exact allowlist, return idempotent, tanpa HTTP redirect | Unit semua phase×role×location, batas redirect tidak diubah untuk menutupi loop |
| R02 | P1 | Restore async race/flicker `main.dart:21`, app gate | Adapter phase existing, no forced initialLocation, hydrate hanya sesudah valid | Widget Completer cold deep link sebelum/sesudah restore |
| R03 | P0 | Role stale/frontend guard dianggap keamanan | Role server QueueApi, scope key role+epoch; backend RBAC tetap | Akun beda role, role change pada nested page, request salah role ditolak backend |
| R04 | P0 | Auth collision account/kiosk, root popUntil | Display exemption tepat, satu navigation owner; no account guard pada device | ADMIN logout/offline/refresh saat kiosk aktif; device tetap terisolasi |
| R05 | P0 | Selector/cookie A/B/C tertukar | Named cookie/selector existing, session GET validates IDs, no URL override | A/C satu context, B context lain; pair/rotate/revoke target saja, duplicate-tab boundary |
| R06 | P1 | Cubit/repository dibuat ulang atau ditutup dua kali | Portal scope di atas child, provider.value mengikuti owner, epoch stabil | Identity assertions instance/create/close counts saat route/back/rebuild/logout |
| R07 | P2 | Tab patient baru mereset filter/draft atau mempertahankan state akun lain | Shared scope + lazy branch, explicit reservation-retap/Back contract | Lima tab, mode/search/scroll/profil, logout/relogin akun sama dan berbeda |
| R08 | P0 | Socket/polling ganda atau scope ruang lama aktif | Satu feed per portal capability; branch tidak membuat PatientUpdates baru | Event burst/navigation/reconnect, socket count sebelum/sesudah leave/close |
| R09 | P0 | TTS replay/utterance lama saat URL/fullscreen berubah | Host display stable, gate/epoch existing, no announce in router/build | Initial/reconnect/manual/Back senyap, CALL sekali, RECALL baru, duplicate event |
| R10 | P2 | Android Back terlalu dini atau membuka portal lama | Modal→detail→root branch→Home→platform; auth replacement evicts scope | System/predictive Back pada root/nested/dialog, relogin different role |
| R11 | P2 | Browser Back/Forward tidak sinkron | Registered declarative locations, no index owner paralel | URL/selected sidebar/branch sama setelah forward/back/copy/paste |
| R12 | P1 | Refresh nested path 404 atau kehilangan extra | Hash awal; GET hydrate; Path strategy menunggu rewrite | Cold `/#/admin/...`, cold ticket no extra; path negative test pada server tanpa fallback |
| R13 | P0 | Kamera/QR masih hidup setelah close/logout | Scanner root modal, dispose/stop existing; QR clear/dispose, auth eviction menang | Close/back/logout/room change saat scan/POST pending; tidak ada POST retry |
| R14 | P2 | Unknown route/raw exception membuka data/loop | Safe error builder, invalid parameter handling, bukan echo URL | Unknown/encoded/invalid IDs, safe home, tanpa raw secret di UI/log |
| R15 | P1 | Provider di navigator yang salah, profile/dialog tidak melihat scope | Root vs branch keys eksplisit; account API bukan catalog DI global | ADMIN editor/QR/profile dari setiap entry, pop target benar |
| R16 | P0 | Unauthorized private UI flash saat session notification | Gate sebelum child, forced removal meski busy; epoch scope baru | Capture before-frame/after-frame logout/role-change pada setiap nested page |
| R17 | P3 | Mengarang reset-password deep link dari nama security panel | Flow publik tidak ada; tetap hanya change password akun | Tidak ada `/reset-password` baru; change password menghapus sesi |
| R18 | P1 | Sesi berubah ketika dialog/editor aktif | Satu redirect, cleanup secret existing; jangan remove Page deklaratif via legacy helper | Activation/ticket/profile/form saat expire/logout dan late result |
| R19 | P0 | Cold URL/Back menerbitkan QR atau booking otomatis | GET-only hydrate, konfirmasi eksplisit untuk mutation, raw payload tidak di URL | Reload ticket/new/doctor 0 POST; setelah action sah tepat satu POST |
| R20 | P0 | Open redirect/API base injection | Internal URI+registry+role allowlist, no arbitrary server URL | Absolute URL, `//`, backslash, encoded traversal, nested from, malicious query |
| R21 | P2 | Fullscreen keluar/pagination reset karena widget remount | Satu display page identity, no URI clock/page/fullscreen | Resize/URL refresh notification tanpa remount, timer visual tetap, fullscreen callback |
| R22 | P1 | go_router major 18/transitive UI tidak resolve atau type clash | Pin candidate, review solver/lock diff, baseline SDK tidak di-upgrade massal | R1 pub get/analyze/tests, Web/APK dan CI source commit |

## H. Implementation Plan R1–R3

Satu pekerjaan implementasi terpadu **setelah R0 dievaluasi/disetujui**, dengan checkpoint internal. Tidak memulai R1 pada audit ini.

### R1 — Foundation

1. Ulang preflight dan jaga empat perubahan lokal serta dokumen setup untracked. Ambil baseline perilaku/counter dari source yang disepakati; jangan mengikutkan file dokter lokal secara otomatis.
2. Tambah dependency kandidat 18.1.1 hanya pada tahap berotorisasi; pub get dan tinjau lock diff, terutama material_ui/cupertino_ui, intl dan SDK pins. Jika gagal, dokumentasikan constraint nyata sebelum memilih kandidat lain, tanpa upgrade Flutter spekulatif.
3. Buat tiga file routing F7 dan unit policy/URI tests. Tentukan registry/path/name/keys sekali, pure policy dan filtered notifier.
4. Ubah `QueueBApp` di `app.dart` menjadi host yang mempertahankan instance router, dengan constructor QueueApi injectable tetap kompatibel dengan test harness. Ganti MaterialApp ke `.router` tanpa mengubah tema/localization/semantics/branding.
5. Integrasikan main restore **sekali** dan public/device bypass. Pertahankan `_SessionGate` dan form login/register melalui adapter state terkontrol; ubah mode dari location, bukan bool lain yang berlomba.
6. Gantikan account popUntil root dengan redirect owner pada perubahan yang sama. Sediakan error/forbidden feedback minimal yang sesuai komponen QueueB, tanpa fitur/reset-password baru.
7. Gunakan compatibility portal host sementara untuk menjaga aplikasi tetap terakses selama R2; registry bukan sistem routing kedua permanen.

File target utama: `apps/client/pubspec.yaml`, `pubspec.lock`, `lib/src/routing/*`, `lib/src/app.dart`, dan bila diperlukan lifecycle bootstrap `lib/main.dart`; test policy/notifier/widget baru. Tidak mengubah backend/API/RBAC/database.

### R2 — Migrasi lima portal

| Urutan | Perubahan terarah | Acceptance sebelum lanjut |
|---|---|---|
| 1. Shared account boundary/profile | Ganti callback profile ke registered child path; profile tetap memakai AccountProfileCubit existing | Logout/role switch menghapus nested route; direct profile punya parent/fallback |
| 2. ADMIN | `admin.dart`, `admin_navigation.dart`, `admin_dashboard.dart`: URI↔section map, stable scope, sembilan children; dialog tetap | Semua modul, shared metadata, lazy slots, sidebar/back/refresh; tidak ada Cubit double create |
| 3. PASIEN | `patient.dart`, bottom-nav adapter dan scope host: lima branches, booking/doctor/ticket adapter | Satu repository/feed, state retention terukur, no POST dari URL, QR/dialog/Back aman |
| 4. PETUGAS | `queue.dart`: parent/profile route dan root modal key; command/room state tetap BLoC | Scanner close/logout/room/date switch dan command lock/reconciliation tetap |
| 5. DOKTER | `doctor.dart` dan callback profil pada app; dashboard/detail modal tetap | Read-only, date filter, owner/Cubit tidak recreate saat profil child |
| 6. PUBLIC DISPLAY | `display.dart` onExit ke safe location; host stable dan account exemption end-to-end | Pair/restore/rotate/revoke A/B/C, TTS/fullscreen/pagination/counter normal |
| 7. Compatibility closure | Lepas permanent local location owner dan legacy page push untuk tujuan yang kini registered | Satu pemilik canonical location; Navigator tersisa hanya modal/picker yang disengaja |

R2 tidak mengubah isi bisnis Cubit/repository atau merancang ulang UI. Pemisahan host/view/provider dibatasi yang diperlukan routing. Jangan mengedit `doctor_dashboard.dart`, `doctor_visual.dart`, `doctor_visual_refresh_test.dart` dan README lokal tanpa koordinasi pemilik; detail dokter dapat tetap melalui modal existing. Nama route/parameter tidak menjadi alasan membuat endpoint baru.

### R3 — Regression dan QA

1. Jalankan unit policy/notifier lalu widget navigation dengan fake API/Completer; perbaiki race sebelum live test.
2. Pertahankan seluruh suite perilaku existing, tambahkan URL/Back assertions dan lifecycle counters. Ganti harness MaterialApp bila diperlukan, bukan menghapus assertion karena implementasi route berubah.
3. Format file berubah, Flutter analyze dan full Flutter tests; Web release dan APK debug dengan define konsisten. Backend regression sesuai scope bila runner/integrasi digunakan; routing tidak mengubah production backend.
4. Browser matrix hash URL, reload/back/forward, auth/role dan 13 kelompok operasional existing; **strict nol HTTP 5xx/P2028**, bukan sekadar label UI PASS. Pisahkan kegagalan environment dari routing memakai diagnostic evidence.
5. Android system Back, session restore secure storage, scanner permission/disposal dan logout dari nested page. Browser fake camera/audio tidak dianggap pengujian perangkat fisik.
6. Semua tes yang menulis hanya pada PostgreSQL lokal `127.0.0.1:5433/capstone_antrean_test` dengan validasi target, fixture unik dan fingerprint cleanup; tidak otomatis menjalankan migration/seed/reset. R0 sendiri tidak menjalankan tahap ini.
7. Gate akhir: hash file terlindungi aman, no secret dalam URL/log/artifact, listener/socket/camera/audio cleanup benar; CI untuk source yang benar-benar dikomit harus sukses. Git hanya sesuai otorisasi pekerjaan implementasi nanti.

## I. Test Strategy

### I1. Tes navigasi existing yang dipetakan eksplisit

Berikut **17 declaration sites**, bukan 17 total runtime cases. Beberapa berada dalam loop role/viewport. Baris merujuk working tree aktual, termasuk baseline lokal yang dilindungi bila disebut; tidak ada test di bawah yang dijalankan ulang pada R0.

| File di `apps/client/test/` | Baris | Perilaku yang wajib dipertahankan |
|---|---:|---|
| `login_ui_test.dart` | 324 | Role backend menentukan portal, logout kembali login |
| `login_ui_test.dart` | 360 | Registrasi memakai public API existing lalu kembali login |
| `doctor_dashboard_test.dart` | 430 | Login DOKTER → dashboard, logout menghapus portal |
| `doctor_cubit_session_widget_test.dart` | 20 | Pergantian akun menutup owner lama, pending profile diabaikan |
| `doctor_cubit_session_widget_test.dart` | 76 | Perubahan role unmount/close dokter |
| `session_test.dart` | 536 | Restore membuka satu patient socket, rotation/disposal benar |
| `session_test.dart` | 574 | Logout menutup ticket route dan private cached UI |
| `session_test.dart` | 640 | Startup tanpa login flash dan role tervalidasi |
| `session_test.dart` | 688 | Offline gate menyembunyikan role routes, retry/logout tersedia |
| `admin_optimization_test.dart` | 63 | Sembilan modul dapat dicapai melalui navigasi langsung UI |
| `admin_integration_stage2e_test.dart` | 257 | Metadata display shared melewati dashboard/navigation/rebuild |
| `admin_integration_stage2e_test.dart` | 300 | Logout pending dashboard membersihkan semua proyeksi |
| `patient_experience_test.dart` | 139 | Home search/filter tetap konsisten ketika berganti tab |
| `patient_mobile_v5_test.dart` | 78 | Lima tab, floating actions dan profil pada viewport/text scaling |
| `patient_mobile_v5_test.dart` | 153 | Filter melewati profil, daftar lazy dan FAB tidak menutup kartu akhir |
| `patient_v2_test.dart` | 260 | Back dari review menjaga pilihan dan tidak POST |
| `staff_compact_test.dart` | 143 | Header profil membuka akun, logout tetap dapat dicapai |

Tambahan suite existing yang harus tetap: `user_profile_test.dart`, `patient_home_v6_test.dart`, `patient_home_swipe_test.dart`, `patient_reservations_test.dart`, `patient_session_cubit_test.dart`, `patient_visits_cubit_test.dart` (termasuk TicketCubit), `one_scan_qr_test.dart`, `staff_snapshot_bloc_test.dart`, `staff_command_bloc_test.dart`, `staff_qr_bloc_test.dart`, `staff_realtime_bloc_test.dart`, `display_device_cubit_test.dart`, `display_snapshot_bloc_test.dart`, `display_announcement_bloc_test.dart`, `display_isolation_bloc_test.dart`, `display_multi_monitor_test.dart`, pairing/V2/V3 display, dan test admin CRUD. Browser `tool/browser-final-e2e.cjs` dan entry `integration_test/` existing menjadi baseline integrasi, bukan bukti deep-link/Back router baru telah diuji.

Indeks 27 file pada C3 mencakup file yang memakai harness/simbol navigasi; suite display tanpa simbol itu tetap diperlukan. Tidak ada test `go_router`/registry baru saat ini. Pengujian direct module URI, nested reload, safe return dan shell Back harus **ditambah**, bukan dianggap ditutup oleh tes klik menu existing.

### I2. Matriks implementasi tes R1–R3

| ID | Area/skenario | Level utama | Assertion penting |
|---|---|---|---|
| T01 | Anonymous pada setiap protected root/child | Unit + widget | Login tanpa private page flash; URI aman tersimpan |
| T02 | Authenticated empat role, termasuk login gagal | Unit + widget | Default home tepat, login gagal tidak consume from, registry roles tidak bocor |
| T03 | Restore pending/valid/expired/offline/storageError | Completer unit/widget + Android | Satu restore, tidak ada loop/flicker; recovery tidak membuang credential |
| T04 | Logout/role switch pada nested page/modal, termasuk akun sama relogin | Widget + browser | Scope epoch baru, late result tak menulis, Back tidak memulihkan data lama |
| T05 | Safe return adversarial | Unit | Tolak URL eksternal/authority/traversal/encoded separator/unknown/secret query/nested from |
| T06 | Unknown path dan invalid parameters | Widget + browser | Error aman, fallback sah, tanpa exception/raw URI rahasia |
| T07 | Sembilan modul ADMIN direct URL | Widget + browser | Active sidebar dan content cocok, satu katalog/Cubit lifetime |
| T08 | ADMIN Back/Forward/refresh, small-screen menu | Browser + widget | History location/section sama, bottom sheet ditutup sesuai target |
| T09 | ADMIN CRUD/editor/bulk/slot/activation | Widget + guarded integration | Konfirmasi/busy/result/reconciliation tetap; kode transient clear pada expiry/logout |
| T10 | Lima branch pasien dan lazy init | Widget + counter | Navigators sesuai konfigurasi; repository/feed tetap satu; profil tidak eager |
| T11 | Home V6 mode/swipe/search dan filters melewati tab | Widget | UI/semantics/scroll sesuai panduan QueueB; tidak menganggap mode sebagai branch keenam |
| T12 | Reservasi list→new→dokter→slot→review→Back | Widget + browser | Pilihan/guard valid, 0 POST sebelum konfirmasi, retap Reservasi sesuai kontrak |
| T13 | Cold ticket/doctor URL tanpa extra, reload | Widget + browser | GET hydrate, owner dan metadata cocok, 404/403 aman, 0 QR/booking POST |
| T14 | QR modal open/issue/expiry/close/logout | Widget + guarded E2E | TicketCubit/timer close sekali, payload dibuang, URL tidak berisi QR |
| T15 | Agenda/profil/name/avatar/password | Widget + integration | Shared data dan read-only role; password sukses menutup sesi, no replay |
| T16 | Android branch/root/detail Back dan predictive Back | Android integration | Overlay→detail→root→Home→platform; tidak membuka role lama |
| T17 | PETUGAS room/assignment/date scope | Widget + integration | Navigator tidak menentukan izin; scope lama dibersihkan, one command lock |
| T18 | Scanner Back/lifecycle/logout saat pending POST | Widget fake controller + Android/browser | Controller stop/dispose, owned modal closure, no automatic POST retry |
| T19 | Semua command staff dan detail/profile child | Existing E2E + route assertions | CALL/RECALL/SKIP/REQUEUE/START/COMPLETE tetap sesuai state machine |
| T20 | DOKTER read-only/date/detail/profile dan expiry | Widget + browser | Tidak ada mutasi antrean; parent Cubit bertahan ketika profile dibuka |
| T21 | Device cold `/display`, restore dan pairing | Widget + browser | Guard akun dilewati, restore satu kali, device GET/backend scope benar |
| T22 | Account login/logout/offline saat kiosk aktif | Widget + browser | Kiosk tidak dipop/diroute ke login; normal account scope tetap evicted |
| T23 | A/C shared context + B context lain | Browser nyata | Named cookies/selector sesuai; rotasi/revoke A tidak mengubah B/C |
| T24 | Independent/duplicate/opener tab | Browser nyata | Tab tanpa selector tidak menebak sesi; duplicate limitation didokumentasikan dan tidak diklaim isolasi mutlak |
| T25 | Device uncertain/rejected/revoked/API base scope | Unit + browser | Tidak POST ulang; no URL apiBase override; tidak tampil snapshot scope lama |
| T26 | Reconnect/manual refresh/initial/resume + CALL/RECALL | BLoC + browser | Baseline senyap, CALL once, RECALL baru, duplicate dedup; no replay akibat routing |
| T27 | Fullscreen/pagination/resize dan router refresh | Widget + browser | Identity host sama, socket satu, paginator tidak reset tanpa alasan |
| T28 | Cross-role/account/device/room boundary | Unit + integration/browser | Tidak ada data lama/subscription ganda, backend RBAC tetap |
| T29 | Hash URL direct/copy/paste/back/forward/reload | Browser | Semua location registered dapat dibuka ulang sesuai sesi; address bar sinkron |
| T30 | Path strategy negative/optional future hosting | Browser/server integration | Tidak mengklaim path refresh siap tanpa fallback; asset/API/socket tidak terkena rewrite |
| T31 | Dependency/platform compatibility | Analyze/unit/Web/APK/CI | Candidate resolve dan build dengan baseline SDK, tidak merusak theme/Material types |
| T32 | Scope resource counts | Unit/widget counters + browser | create/close/listener/socket/audio/camera sesuai owner, tidak naik setiap route notification |

Counter lifetime dapat diinjeksi mengikuti pola repository/feed/timer fake existing; tidak membuat backend API observability baru. Browser Web memory-session dan Android secure-store harus diuji terpisah. Device auth tidak diuji hanya dengan mock QueueApi akun.

## J. Migration Readiness

**READY WITH CONDITIONS.** Tidak ditemukan kebutuhan mengganti state management atau backend untuk mulai merencanakan R1–R3. SDK memenuhi constraint kandidat package; existing scope/repository memberi fondasi yang dapat dipertahankan. Risiko terbesar berada pada root session navigation, ownership saat shell memisah view, dan sesi kiosk, bukan kekurangan fitur routing dasar.

Syarat sebelum implementasi dimulai:

1. Pengguna menyetujui blueprint R0 dan scope pekerjaan terpadu R1–R3. **Belum ada otorisasi memulai R1 pada audit ini.**
2. Terima kontrak hash awal, lima branch pasien lazy serta Back/retap pada F4, termasuk perbedaan dari tiga slot existing; bila tidak diterima, pilih ShellRoute pasien satu Navigator secara sadar sebelum coding, bukan mengganti semantik di tengah implementasi.
3. Dependency candidate di-resolve dan diverifikasi pada R1; upgrade SDK tidak diasumsikan, lockfile tidak disentuh R0.
4. Sepakati GET-only hydration ticket/doctor dan batas modal/QR. User/device credentials tidak menjadi URL. Protected return tetap internal dan role-checked.
5. Pastikan lifecycle tests mendahului live QA dan tidak ada dua owner navigasi root. Riwayat patch snapshot/latency host bukan alasan menonaktifkan strict gate ketika menguji routing.
6. Koordinasikan empat perubahan lokal terlindungi dan dokumen setup sebelum Git implementasi; audit memakai working tree aktual, CI baseline menguji source commit. Tidak mengikutkan file lokal tersebut secara implisit. Saat audit berakhir remote maju ke `17e8653` hanya untuk CONTRIBUTING.md; baca perubahan workflow itu dan sinkronkan baseline secara aman sebelum implementasi, tanpa menimpa pekerjaan lokal.

R0 bukan approval production, bukan bukti browser Back/Android deep link baru lulus, dan bukan klaim anomaly development lama telah ditemukan penulisnya. Tidak ada pengujian baru atau koneksi database dalam audit ini.

## K. Final Recommendations

Keputusan desain yang direkomendasikan: go_router 18.1.1 sebagai kandidat pin, satu router/notifier, QueueApi tetap auth authority klien, ADMIN ShellRoute, PASIEN lazy stateful shell dengan kontrak eksplisit, GoRoute sederhana untuk staff/dokter, serta `/display` tunggal yang independen dari auth akun. Pertahankan hash pada pekerjaan awal dan dialog transient yang sudah berfungsi.

Hal yang belum dapat dinyatakan selesai hanya melalui source audit:

- Hasil solver/type compatibility major 18 beserta material_ui/cupertino_ui; dibuktikan di R1, bukan lewat dugaan kompatibilitas semata.
- Perilaku browser history dan Android/predictive Back nyata sesudah wiring shell; diuji R3 sesuai kontrak, bukan diasumsikan dari klik menu sekarang.
- Hosting PathUrlStrategy/rewrite/TLS/base path tujuan belum dipastikan. Default blueprint tidak bergantung padanya.
- Biaya memori dan frekuensi request dari lima branch yang telah dikunjungi; ukur sebelum mengklaim keuntungan stateful shell.
- Duplicate-tab cookie/selector dan isolasi speaker pada satu Flutter engine tidak diperbaiki go_router. Acceptance perangkat nyata tetap terpisah.
- Branch history tab 4 dan DoctorProfessionalDialog tanpa caller produksi tidak otomatis diaktifkan kembali. Jika menjadi kebutuhan produk, bahas sebagai scope fitur terpisah.

### K1. Integritas hasil R0

Satu-satunya file yang dibuat oleh tugas ini adalah `docs/frontend/GO_ROUTER_MIGRATION_AUDIT_R0.md`. Tidak ada source produksi, dependency, lockfile, backend, environment, CI, atau dokumen setup yang diubah. File lokal yang sudah dirty dan backup/untracked tetap dipertahankan. Hash empat file historis, pubspec/lockfile, serta panduan setup diperiksa sebelum/sesudah audit. Tidak ada staging, commit, push, pemasangan go_router, build/test, atau operasi database. R1 menunggu evaluasi pengguna.
