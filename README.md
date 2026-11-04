# Kliinik Kelompok B - Sistem Manajemen Antrean Digital

Repository utama Capstone Project STSI4440
Program Studi Sistem Informasi
Universitas Terbuka.

## Status

Backend MVP Kliinik Kelompok B selesai. Aplikasi Flutter di `apps/client` menyediakan portal PASIEN (USER), ADMIN, PETUGAS, DOKTER, dan Public Display, termasuk tiket digital, cetak, dan unduh PDF.

Kontrak API: [Panduan Integrasi Backend](docs/backend/API_INTEGRATION_GUIDE.md).
Menjalankan aplikasi: [Panduan Instalasi Lokal](docs/setup/LOCAL_INSTALLATION_GUIDE.md).
Acuan tampilan: [Panduan UI/UX Kliinik Kelompok B](docs/frontend/QUEUEB_UI_UX_GUIDELINES.md).

## Tujuan

Mengembangkan sistem manajemen antrean digital untuk
mendukung proses pelayanan secara terintegrasi melalui:

- Reservasi layanan
- Tiket antrean digital
- QR Check-In
- Real-Time Monitoring
- Posisi dan estimasi waktu tunggu
- Operasional petugas
- Public Display
- Text-to-Speech
- Dashboard administrasi

## Struktur Repository

```text
apps/
├── client/     Flutter Android dan Web untuk lima portal
├── web/        Folder tambahan; belum berisi source aplikasi lengkap
└── api/        NestJS Backend

docs/
├── requirements/
├── architecture/
├── database/
├── dfd/
├── uml/
├── ui-ux/
├── api/
└── testing/

infra/
└── docker/

scripts/
```
