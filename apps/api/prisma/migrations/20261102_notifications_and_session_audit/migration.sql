-- Additive; no historical notifications or reconstruction of past auth activity.
ALTER TABLE "pengguna" ADD COLUMN "audit_ref" UUID NOT NULL DEFAULT gen_random_uuid();
CREATE UNIQUE INDEX "pengguna_audit_ref_key" ON "pengguna"("audit_ref");
ALTER TABLE "sesi_pengguna" ADD COLUMN "audit_ref" UUID NOT NULL DEFAULT gen_random_uuid();
CREATE UNIQUE INDEX "sesi_pengguna_audit_ref_key" ON "sesi_pengguna"("audit_ref");
ALTER TABLE "notifikasi" ADD COLUMN "peristiwa_antrean_id" UUID;
CREATE UNIQUE INDEX "notifikasi_peristiwa_antrean_id_key" ON "notifikasi"("peristiwa_antrean_id");
CREATE INDEX "idx_notifikasi_inbox" ON "notifikasi"("pengguna_id", "dibuat_pada", "id");

CREATE TABLE "audit_sesi" (
  "id" UUID NOT NULL PRIMARY KEY,
  "request_id" UUID NOT NULL,
  "akun_ref" UUID,
  "aktor_ref" UUID,
  "sesi_ref" UUID,
  "aksi" VARCHAR(20) NOT NULL CHECK ("aksi" IN ('LOGIN','REFRESH','LOGOUT','CABUT_SESI','BACA_AUDIT')),
  "hasil" VARCHAR(12) NOT NULL CHECK ("hasil" IN ('BERHASIL','DITOLAK','ERROR')),
  "alasan" VARCHAR(40) NOT NULL,
  "klien" VARCHAR(16) NOT NULL CHECK ("klien" IN ('WEB','ANDROID','IOS','DESKTOP','UNKNOWN')),
  "sumber" VARCHAR(16) NOT NULL DEFAULT 'UNKNOWN' CHECK ("sumber" = 'UNKNOWN'),
  "jumlah_sesi" INTEGER,
  "terjadi_pada" TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);
CREATE INDEX "audit_sesi_terjadi_pada_id_idx" ON "audit_sesi"("terjadi_pada", "id");
CREATE INDEX "audit_sesi_akun_ref_terjadi_pada_idx" ON "audit_sesi"("akun_ref", "terjadi_pada");
CREATE INDEX "audit_sesi_sesi_ref_terjadi_pada_idx" ON "audit_sesi"("sesi_ref", "terjadi_pada");

-- The notification and queue event commit/rollback together, including One-Scan.
-- A committed event ID is the deduplication key; no socket retry creates a copy.
CREATE FUNCTION queueb_notifikasi_peristiwa() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  pemilik UUID;
  nomor TEXT;
  nama_layanan TEXT;
  nama_ruang TEXT;
  judul_pesan TEXT;
  isi TEXT;
  jenis_pesan "jenis_notifikasi";
BEGIN
  IF NEW.status_sesudah IS NULL OR
     (NEW.status_sebelum IS NOT DISTINCT FROM NEW.status_sesudah AND NEW.tipe <> 'RECALL') THEN
    RETURN NEW;
  END IF;
  SELECT t.pengguna_id, trim(l.prefix_antrean) || '-' || lpad(t.nomor_urut::text, greatest(3, length(t.nomor_urut::text)), '0'), l.nama, k.nama
    INTO pemilik, nomor, nama_layanan, nama_ruang
    FROM tiket_antrean t JOIN layanan l ON l.id=t.layanan_id
    LEFT JOIN loket k ON k.id=t.loket_id WHERE t.id=NEW.tiket_antrean_id;
  IF pemilik IS NULL THEN RETURN NEW; END IF;
  jenis_pesan := 'PERUBAHAN_STATUS';
  CASE NEW.status_sesudah
    WHEN 'DIPESAN' THEN judul_pesan := 'Reservasi berhasil'; isi := 'Reservasi Anda telah tersimpan.';
    WHEN 'CHECK_IN' THEN judul_pesan := 'Check-in berhasil'; isi := 'Kehadiran Anda telah dicatat.';
    WHEN 'MENUNGGU' THEN judul_pesan := 'Masuk antrean'; isi := 'Anda terdaftar dalam antrean. Pantau status untuk panggilan berikutnya.';
    WHEN 'DIPANGGIL' THEN
      judul_pesan := CASE WHEN NEW.tipe='RECALL' THEN 'Nomor dipanggil ulang' ELSE 'Nomor Anda dipanggil' END;
      isi := 'Silakan menuju ' || coalesce(nama_ruang, 'ruang pelayanan') || '.';
      jenis_pesan := 'PEMANGGILAN';
    WHEN 'DILAYANI' THEN judul_pesan := 'Pelayanan dimulai'; isi := 'Status tiket Anda telah berubah menjadi dilayani.';
    WHEN 'SELESAI' THEN judul_pesan := 'Pelayanan selesai'; isi := 'Pelayanan tiket Anda telah selesai.';
    WHEN 'DILEWATI' THEN judul_pesan := 'Nomor antrean dilewati'; isi := 'Hubungi petugas untuk tindak lanjut antrean Anda.';
    WHEN 'DIBATALKAN' THEN judul_pesan := 'Reservasi dibatalkan'; isi := 'Tiket Anda telah dibatalkan. Hubungi petugas jika membutuhkan tindak lanjut.';
    ELSE RETURN NEW;
  END CASE;
  INSERT INTO notifikasi (id,pengguna_id,tiket_antrean_id,peristiwa_antrean_id,jenis,judul,pesan,dibuat_pada)
    VALUES (gen_random_uuid(),pemilik,NEW.tiket_antrean_id,NEW.id,jenis_pesan,judul_pesan,
      nomor || ' · ' || nama_layanan || '. ' || isi, clock_timestamp())
    ON CONFLICT (peristiwa_antrean_id) DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE TRIGGER queueb_notifikasi_peristiwa_insert
AFTER INSERT ON "peristiwa_antrean" FOR EACH ROW EXECUTE FUNCTION queueb_notifikasi_peristiwa();
