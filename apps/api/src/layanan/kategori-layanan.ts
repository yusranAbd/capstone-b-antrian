import { KategoriLayanan } from '../generated/prisma/client';

/** Compatibility for clients that predate the explicit category field. */
export function kategoriDariKode(kode: string): KategoriLayanan {
  switch (kode.trim().toUpperCase()) {
    case 'PENDAFTARAN':
    case 'DAFTAR':
    case 'REGISTRASI':
    case 'ADMINISTRASI':
      return KategoriLayanan.PENDAFTARAN;
    case 'APOTEK':
    case 'APOTIK':
      return KategoriLayanan.APOTEK;
    case 'LABORATORIUM':
      return KategoriLayanan.LABORATORIUM;
    case 'RADIOLOGI':
      return KategoriLayanan.RADIOLOGI;
    case 'KASIR':
      return KategoriLayanan.KASIR;
    case 'REKAM_MEDIS':
      return KategoriLayanan.REKAM_MEDIS;
    default:
      return KategoriLayanan.POLIKLINIK;
  }
}
