import { Injectable } from '@nestjs/common';

import { ReservasiService } from '../reservasi/reservasi.service';

type DataReservasi = Awaited<ReturnType<ReservasiService['findOne']>>;

@Injectable()
export class TiketService {
  constructor(private readonly reservasiService: ReservasiService) {}

  // ==========================================
  // DAFTAR TIKET PENGGUNA
  // ==========================================

  async findAll(penggunaId: string) {
    const reservasi = await this.reservasiService.findAll(penggunaId);

    return reservasi.map((tiket) => this.formatTiket(tiket));
  }

  // ==========================================
  // DETAIL TIKET PENGGUNA
  // ==========================================

  async findOne(id: string, penggunaId: string) {
    const tiket = await this.reservasiService.findOne(id, penggunaId);

    return this.formatTiket(tiket);
  }

  // ==========================================
  // FORMAT TIKET DIGITAL
  // ==========================================

  private formatTiket(tiket: DataReservasi) {
    const prefix = tiket.layanan.prefixAntrean.trim();

    const nomor = String(tiket.nomorUrut).padStart(3, '0');

    const nomorAntrean = `${prefix}-${nomor}`;

    // PostgreSQL DATE direpresentasikan
    // oleh Prisma sebagai Date pada UTC.
    const tanggalPelayanan = tiket.tanggalAntrean.toISOString().slice(0, 10);

    return {
      ...tiket,
      nomorAntrean,
      tanggalPelayanan,
    };
  }
}
