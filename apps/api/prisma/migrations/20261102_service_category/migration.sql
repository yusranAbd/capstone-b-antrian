-- Additive: preserve IDs, codes, reservations and all existing relationships.
CREATE TYPE "kategori_layanan" AS ENUM (
  'POLIKLINIK', 'PENDAFTARAN', 'APOTEK', 'LABORATORIUM',
  'RADIOLOGI', 'KASIR', 'REKAM_MEDIS', 'LAINNYA'
);
ALTER TABLE "layanan" ADD COLUMN "kategori" "kategori_layanan" NOT NULL DEFAULT 'POLIKLINIK';
-- One-time compatibility mapping. Subsequent code edits do not change category.
UPDATE "layanan" SET "kategori" = CASE
  WHEN UPPER(TRIM("kode")) IN ('PENDAFTARAN', 'DAFTAR', 'REGISTRASI', 'ADMINISTRASI') THEN 'PENDAFTARAN'
  WHEN UPPER(TRIM("kode")) IN ('APOTEK', 'APOTIK') THEN 'APOTEK'
  WHEN UPPER(TRIM("kode")) = 'LABORATORIUM' THEN 'LABORATORIUM'
  WHEN UPPER(TRIM("kode")) = 'RADIOLOGI' THEN 'RADIOLOGI'
  WHEN UPPER(TRIM("kode")) = 'KASIR' THEN 'KASIR'
  WHEN UPPER(TRIM("kode")) = 'REKAM_MEDIS' THEN 'REKAM_MEDIS'
  ELSE 'POLIKLINIK'
END::"kategori_layanan";
