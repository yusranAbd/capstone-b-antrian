-- CreateEnum
CREATE TYPE "peran_pengguna" AS ENUM ('USER', 'PETUGAS', 'ADMIN');

-- CreateEnum
CREATE TYPE "status_tiket" AS ENUM ('DIPESAN', 'CHECK_IN', 'MENUNGGU', 'DIPANGGIL', 'DILAYANI', 'SELESAI', 'DILEWATI', 'DIBATALKAN');

-- CreateEnum
CREATE TYPE "hari_layanan" AS ENUM ('SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT', 'SABTU', 'MINGGU');

-- CreateEnum
CREATE TYPE "jenis_notifikasi" AS ENUM ('INFORMASI', 'PENGINGAT', 'PEMANGGILAN', 'PERUBAHAN_STATUS');

-- CreateTable
CREATE TABLE "pengguna" (
    "id" UUID NOT NULL,
    "nama" VARCHAR(150) NOT NULL,
    "email" VARCHAR(150) NOT NULL,
    "kata_sandi_hash" VARCHAR(255) NOT NULL,
    "peran" "peran_pengguna" NOT NULL,
    "aktif" BOOLEAN NOT NULL DEFAULT true,
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "diperbarui_pada" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "pengguna_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "layanan" (
    "id" UUID NOT NULL,
    "kode" VARCHAR(20) NOT NULL,
    "nama" VARCHAR(150) NOT NULL,
    "deskripsi" TEXT,
    "prefix_antrean" VARCHAR(5) NOT NULL,
    "durasi_dasar_menit" INTEGER NOT NULL,
    "aktif" BOOLEAN NOT NULL DEFAULT true,
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "diperbarui_pada" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "layanan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "loket" (
    "id" UUID NOT NULL,
    "layanan_id" UUID NOT NULL,
    "kode" VARCHAR(20) NOT NULL,
    "nama" VARCHAR(100) NOT NULL,
    "lokasi" VARCHAR(150),
    "aktif" BOOLEAN NOT NULL DEFAULT true,
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "diperbarui_pada" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "loket_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "jadwal_layanan" (
    "id" UUID NOT NULL,
    "layanan_id" UUID NOT NULL,
    "hari" "hari_layanan" NOT NULL,
    "jam_buka" TIME(0) NOT NULL,
    "jam_tutup" TIME(0) NOT NULL,
    "kapasitas_harian" INTEGER NOT NULL,
    "aktif" BOOLEAN NOT NULL DEFAULT true,
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "diperbarui_pada" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "jadwal_layanan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "penugasan_petugas" (
    "id" UUID NOT NULL,
    "petugas_id" UUID NOT NULL,
    "loket_id" UUID NOT NULL,
    "tanggal_mulai" DATE NOT NULL,
    "tanggal_selesai" DATE,
    "aktif" BOOLEAN NOT NULL DEFAULT true,
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "penugasan_petugas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tiket_antrean" (
    "id" UUID NOT NULL,
    "pengguna_id" UUID NOT NULL,
    "layanan_id" UUID NOT NULL,
    "loket_id" UUID,
    "tanggal_antrean" DATE NOT NULL,
    "nomor_urut" INTEGER NOT NULL,
    "kode_tiket" VARCHAR(30) NOT NULL,
    "status" "status_tiket" NOT NULL DEFAULT 'DIPESAN',
    "token_qr_hash" VARCHAR(255),
    "qr_kedaluwarsa_pada" TIMESTAMPTZ(6),
    "check_in_pada" TIMESTAMPTZ(6),
    "dipanggil_pada" TIMESTAMPTZ(6),
    "pelayanan_dimulai_pada" TIMESTAMPTZ(6),
    "pelayanan_selesai_pada" TIMESTAMPTZ(6),
    "versi" INTEGER NOT NULL DEFAULT 1,
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "diperbarui_pada" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "tiket_antrean_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "urutan_antrean_harian" (
    "id" UUID NOT NULL,
    "layanan_id" UUID NOT NULL,
    "tanggal" DATE NOT NULL,
    "nomor_terakhir" INTEGER NOT NULL DEFAULT 0,
    "diperbarui_pada" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "urutan_antrean_harian_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "peristiwa_antrean" (
    "id" UUID NOT NULL,
    "tiket_antrean_id" UUID NOT NULL,
    "aktor_id" UUID,
    "tipe" VARCHAR(50) NOT NULL,
    "status_sebelum" "status_tiket",
    "status_sesudah" "status_tiket",
    "data_tambahan" JSONB,
    "versi" INTEGER NOT NULL DEFAULT 1,
    "terjadi_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "peristiwa_antrean_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "perangkat_tampilan" (
    "id" UUID NOT NULL,
    "layanan_id" UUID NOT NULL,
    "nama" VARCHAR(100) NOT NULL,
    "token_hash" VARCHAR(255) NOT NULL,
    "pengaturan_audio" JSONB,
    "aktif" BOOLEAN NOT NULL DEFAULT true,
    "terakhir_aktif_pada" TIMESTAMPTZ(6),
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "diperbarui_pada" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "perangkat_tampilan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sesi_pengguna" (
    "id" UUID NOT NULL,
    "pengguna_id" UUID NOT NULL,
    "token_refresh_hash" VARCHAR(255) NOT NULL,
    "nama_perangkat" VARCHAR(150),
    "kedaluwarsa_pada" TIMESTAMPTZ(6) NOT NULL,
    "dicabut_pada" TIMESTAMPTZ(6),
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sesi_pengguna_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifikasi" (
    "id" UUID NOT NULL,
    "pengguna_id" UUID NOT NULL,
    "tiket_antrean_id" UUID,
    "jenis" "jenis_notifikasi" NOT NULL,
    "judul" VARCHAR(150) NOT NULL,
    "pesan" TEXT NOT NULL,
    "dibaca_pada" TIMESTAMPTZ(6),
    "dibuat_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifikasi_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "pengguna_email_key" ON "pengguna"("email");

-- CreateIndex
CREATE UNIQUE INDEX "layanan_kode_key" ON "layanan"("kode");

-- CreateIndex
CREATE INDEX "loket_layanan_id_idx" ON "loket"("layanan_id");

-- CreateIndex
CREATE UNIQUE INDEX "loket_layanan_id_kode_key" ON "loket"("layanan_id", "kode");

-- CreateIndex
CREATE INDEX "jadwal_layanan_layanan_id_idx" ON "jadwal_layanan"("layanan_id");

-- CreateIndex
CREATE UNIQUE INDEX "jadwal_layanan_layanan_id_hari_key" ON "jadwal_layanan"("layanan_id", "hari");

-- CreateIndex
CREATE INDEX "penugasan_petugas_petugas_id_idx" ON "penugasan_petugas"("petugas_id");

-- CreateIndex
CREATE INDEX "penugasan_petugas_loket_id_idx" ON "penugasan_petugas"("loket_id");

-- CreateIndex
CREATE INDEX "penugasan_petugas_tanggal_mulai_tanggal_selesai_idx" ON "penugasan_petugas"("tanggal_mulai", "tanggal_selesai");

-- CreateIndex
CREATE UNIQUE INDEX "tiket_antrean_kode_tiket_key" ON "tiket_antrean"("kode_tiket");

-- CreateIndex
CREATE UNIQUE INDEX "tiket_antrean_token_qr_hash_key" ON "tiket_antrean"("token_qr_hash");

-- CreateIndex
CREATE INDEX "tiket_antrean_pengguna_id_idx" ON "tiket_antrean"("pengguna_id");

-- CreateIndex
CREATE INDEX "tiket_antrean_layanan_id_idx" ON "tiket_antrean"("layanan_id");

-- CreateIndex
CREATE INDEX "tiket_antrean_loket_id_idx" ON "tiket_antrean"("loket_id");

-- CreateIndex
CREATE INDEX "tiket_antrean_tanggal_antrean_status_idx" ON "tiket_antrean"("tanggal_antrean", "status");

-- CreateIndex
CREATE UNIQUE INDEX "tiket_antrean_layanan_id_tanggal_antrean_nomor_urut_key" ON "tiket_antrean"("layanan_id", "tanggal_antrean", "nomor_urut");

-- CreateIndex
CREATE INDEX "urutan_antrean_harian_layanan_id_idx" ON "urutan_antrean_harian"("layanan_id");

-- CreateIndex
CREATE UNIQUE INDEX "urutan_antrean_harian_layanan_id_tanggal_key" ON "urutan_antrean_harian"("layanan_id", "tanggal");

-- CreateIndex
CREATE INDEX "peristiwa_antrean_tiket_antrean_id_idx" ON "peristiwa_antrean"("tiket_antrean_id");

-- CreateIndex
CREATE INDEX "peristiwa_antrean_aktor_id_idx" ON "peristiwa_antrean"("aktor_id");

-- CreateIndex
CREATE INDEX "peristiwa_antrean_terjadi_pada_idx" ON "peristiwa_antrean"("terjadi_pada");

-- CreateIndex
CREATE UNIQUE INDEX "perangkat_tampilan_token_hash_key" ON "perangkat_tampilan"("token_hash");

-- CreateIndex
CREATE INDEX "perangkat_tampilan_layanan_id_idx" ON "perangkat_tampilan"("layanan_id");

-- CreateIndex
CREATE UNIQUE INDEX "sesi_pengguna_token_refresh_hash_key" ON "sesi_pengguna"("token_refresh_hash");

-- CreateIndex
CREATE INDEX "sesi_pengguna_pengguna_id_idx" ON "sesi_pengguna"("pengguna_id");

-- CreateIndex
CREATE INDEX "sesi_pengguna_kedaluwarsa_pada_idx" ON "sesi_pengguna"("kedaluwarsa_pada");

-- CreateIndex
CREATE INDEX "notifikasi_pengguna_id_idx" ON "notifikasi"("pengguna_id");

-- CreateIndex
CREATE INDEX "notifikasi_tiket_antrean_id_idx" ON "notifikasi"("tiket_antrean_id");

-- CreateIndex
CREATE INDEX "notifikasi_dibaca_pada_idx" ON "notifikasi"("dibaca_pada");

-- AddForeignKey
ALTER TABLE "loket" ADD CONSTRAINT "loket_layanan_id_fkey" FOREIGN KEY ("layanan_id") REFERENCES "layanan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "jadwal_layanan" ADD CONSTRAINT "jadwal_layanan_layanan_id_fkey" FOREIGN KEY ("layanan_id") REFERENCES "layanan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "penugasan_petugas" ADD CONSTRAINT "penugasan_petugas_petugas_id_fkey" FOREIGN KEY ("petugas_id") REFERENCES "pengguna"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "penugasan_petugas" ADD CONSTRAINT "penugasan_petugas_loket_id_fkey" FOREIGN KEY ("loket_id") REFERENCES "loket"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tiket_antrean" ADD CONSTRAINT "tiket_antrean_pengguna_id_fkey" FOREIGN KEY ("pengguna_id") REFERENCES "pengguna"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tiket_antrean" ADD CONSTRAINT "tiket_antrean_layanan_id_fkey" FOREIGN KEY ("layanan_id") REFERENCES "layanan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tiket_antrean" ADD CONSTRAINT "tiket_antrean_loket_id_fkey" FOREIGN KEY ("loket_id") REFERENCES "loket"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "urutan_antrean_harian" ADD CONSTRAINT "urutan_antrean_harian_layanan_id_fkey" FOREIGN KEY ("layanan_id") REFERENCES "layanan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "peristiwa_antrean" ADD CONSTRAINT "peristiwa_antrean_tiket_antrean_id_fkey" FOREIGN KEY ("tiket_antrean_id") REFERENCES "tiket_antrean"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "peristiwa_antrean" ADD CONSTRAINT "peristiwa_antrean_aktor_id_fkey" FOREIGN KEY ("aktor_id") REFERENCES "pengguna"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "perangkat_tampilan" ADD CONSTRAINT "perangkat_tampilan_layanan_id_fkey" FOREIGN KEY ("layanan_id") REFERENCES "layanan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sesi_pengguna" ADD CONSTRAINT "sesi_pengguna_pengguna_id_fkey" FOREIGN KEY ("pengguna_id") REFERENCES "pengguna"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifikasi" ADD CONSTRAINT "notifikasi_pengguna_id_fkey" FOREIGN KEY ("pengguna_id") REFERENCES "pengguna"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifikasi" ADD CONSTRAINT "notifikasi_tiket_antrean_id_fkey" FOREIGN KEY ("tiket_antrean_id") REFERENCES "tiket_antrean"("id") ON DELETE SET NULL ON UPDATE CASCADE;
