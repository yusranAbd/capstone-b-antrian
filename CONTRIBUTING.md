# Panduan Kontribusi

 

Panduan ini digunakan agar proses pengembangan Capstone Project tetap terstruktur, aman, dan mudah dikolaborasikan.

 

## 1. Clone Repository

 

Pastikan sudah memiliki akun GitHub dan akses ke repository.

 

```powershell

git clone https://github.com/yusranAbd/capstone-b-antrian.git

cd capstone-b-antrian

```

 

Pastikan berada di branch utama:

 

```powershell

git branch

```

 

Hasil yang diharapkan:

 

```text

* main

```

 

## 2. Cek Development Environment

 

Jalankan:

 

```powershell

.\scripts\check-env.ps1

```

 

Tools utama yang digunakan:

 

- Git

- Node.js 24 LTS

- Docker Desktop

- Flutter

- Dart

- Java

- ADB

 

Tidak semua anggota wajib menginstal seluruh tools jika hanya mengerjakan dokumentasi.

 

## 3. Siapkan Environment Variable

 

Salin file contoh environment:

 

```powershell

Copy-Item .env.example .env

```

 

File `.env` hanya digunakan pada komputer masing-masing dan tidak boleh di-commit ke GitHub.

 

## 4. Jalankan PostgreSQL

 

Pastikan Docker Desktop aktif.

 

```powershell

docker compose up -d

```

 

Cek status:

 

```powershell

docker compose ps

```

 

Database harus berstatus:

 

```text

healthy

```

 

## 5. Ambil Update Terbaru

 

Sebelum mulai bekerja:

 

```powershell

git checkout main

git pull origin main

```

 

Hal ini memastikan project lokal menggunakan versi terbaru dari GitHub.

 

## 6. Jangan Bekerja Langsung di `main`

 

Setiap pekerjaan dilakukan pada branch terpisah.

 

Gunakan pola:

 

```text

feature/*    fitur baru

fix/*        perbaikan bug

docs/*       dokumentasi

test/*       pengujian

refactor/*   refactor kode

chore/*      konfigurasi atau maintenance

```

 

Contoh:

 

```powershell

git checkout -b feature/authentication

```

 

atau:

 

```powershell

git checkout -b docs/update-uml

```

 

## 7. Commit Message

 

Gunakan format:

 

```text

type(scope): description

```

 

Contoh:

 

```text

feat(auth): implement JWT authentication

feat(queue): add queue state transitions

fix(qr): resolve QR validation issue

docs(uml): update sequence diagram

test(queue): add queue lifecycle tests

```

 

Jenis commit yang digunakan:

 

```text

feat

fix

docs

test

refactor

chore

ci

```

 

## 8. Kirim Perubahan

 

Setelah pekerjaan selesai:

 

```powershell

git status

git add .

git commit -m "type(scope): description"

git push -u origin nama-branch

```

 

Contoh:

 

```powershell

git push -u origin docs/update-uml

```

 

## 9. Pull Request

 

Setelah branch berhasil di-push, buat Pull Request menuju:

 

```text

main

```

 

Alur kontribusi:

 

```text

Task / Issue

    ↓

Update main

    ↓

Buat branch

    ↓

Kerjakan

    ↓

Test

    ↓

Commit

    ↓

Push

    ↓

Pull Request

    ↓

Review / CI

    ↓

Merge

    ↓

DONE

```

 

## 10. GitHub Projects

 

Status pekerjaan menggunakan:

 

```text

BACKLOG

READY

IN PROGRESS

REVIEW

DONE

```

 

Gunakan Issue Template jika membuat:

 

- Bug Report

- Feature Request

- Project Task

 

## 11. Keamanan

 

Dilarang melakukan commit terhadap:

 

```text

.env

password

API key

JWT secret

database credential

Android keystore

key.properties

*.jks

*.keystore

data pribadi pengguna

```

 

Gunakan `.env.example` untuk contoh konfigurasi.

 

## 12. Dokumentasi

 

Dokumentasi teknis disimpan pada folder:

 

```text

docs/

```

 

Dokumentasi akademik seperti proposal, laporan, berita acara, PPT, poster, dan video disimpan pada Google Drive tim.

 

## 13. Definition of Done

 

Task dapat dianggap selesai jika:

 

- requirement sudah terpenuhi;

- pekerjaan sudah selesai;

- tidak terdapat error penting;

- pengujian sudah dilakukan jika diperlukan;

- dokumentasi sudah diperbarui;

- evidence tersedia jika diperlukan;

- Pull Request sudah direview jika relevan;

- status GitHub Project sudah dipindahkan ke `DONE`.

 

## 14. Menjalankan Aplikasi

 

Setelah backend tersedia:

 

```powershell

cd apps\api

npm install

npm run start:dev

```

 

Setelah Flutter tersedia:

 

```powershell

cd apps\client

flutter pub get

flutter run

```

 

## 15. Catatan

 

Branch `main` digunakan untuk versi project yang stabil.

 

Setiap perubahan sebaiknya mengikuti alur:

 

```text

branch → commit → push → Pull Request → review → merge

```

 

Panduan setup development yang lebih lengkap tersedia di:

 

```text

docs/development/SETUP.md

```
