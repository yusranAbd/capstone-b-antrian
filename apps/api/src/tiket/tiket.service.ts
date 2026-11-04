import {
  Injectable,
  NotFoundException,
  Optional,
  ServiceUnavailableException,
} from '@nestjs/common';

import {
  ModeReservasi,
  PeranPengguna,
  Prisma,
  StatusTiket,
} from '../generated/prisma/client';
import { waktuPelayanan } from '../hospital/hospital-context';
import { PrismaService } from '../prisma/prisma.service';
import { ReservasiService } from '../reservasi/reservasi.service';

type DataReservasi = Awaited<ReturnType<ReservasiService['findOne']>>;

export type AlasanPosisiTiket =
  | 'MODE_ANTREAN_BELUM_DIDUKUNG'
  | 'STATUS_BUKAN_MENUNGGU'
  | 'BUKAN_HARI_PELAYANAN'
  | 'LAYANAN_TIDAK_AKTIF'
  | 'JADWAL_LAYANAN_TIDAK_AKTIF'
  | 'LOKET_PELAYANAN_BELUM_TERSEDIA'
  | 'BELUM_MASUK_ANTREAN';

export interface TiketDispatch {
  versiSkema: 1;
  tiketId: string;
  status: StatusTiket;
  tanggalPelayanan: string;
  diperolehPada: string;
  checkInPada: string | null;
  layanan: {
    id: string;
    kode: string;
    nama: string;
    modeReservasi: ModeReservasi;
  };
  loketTujuan: { id: string; kode: string; nama: string } | null;
  posisiAntrean: number | null;
  jumlahDiDepan: number | null;
  alasanPosisi: AlasanPosisiTiket | null;
  sedangDilayani: Array<{
    loketId: string;
    kodeLoket: string;
    nomorAntrean: string;
  }>;
}

@Injectable()
export class TiketService {
  constructor(
    private readonly reservasiService: ReservasiService,
    // Existing standalone ticket readers only need ReservasiService. The module
    // supplies PrismaService for the additive dispatch read model at runtime.
    @Optional() private readonly prisma?: PrismaService,
  ) {}

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

  /**
   * Owned-ticket read model only: daily queue rank uses the same service/day,
   * MENUNGGU membership and (urutanMasukAntrean, id) order as daily CALL.
   * Hospital modes deliberately return no rank: their room/slot eligibility
   * must not be approximated by a service-wide FIFO number.
   */
  async dispatch(id: string, penggunaId: string): Promise<TiketDispatch> {
    const prisma = this.prisma;
    if (!prisma) {
      throw new ServiceUnavailableException(
        'Informasi antrean belum tersedia.',
      );
    }
    return prisma.$transaction(
      async (tx) => {
        const now = new Date();
        const today = waktuPelayanan(now);
        const ticket = await tx.tiketAntrean.findFirst({
          where: { id, penggunaId },
          select: {
            id: true,
            layananId: true,
            status: true,
            tanggalAntrean: true,
            checkInPada: true,
            urutanMasukAntrean: true,
            layanan: {
              select: {
                id: true,
                kode: true,
                nama: true,
                prefixAntrean: true,
                modeReservasi: true,
                aktif: true,
              },
            },
            loket: {
              select: {
                id: true,
                kode: true,
                nama: true,
                layananId: true,
                aktif: true,
              },
            },
          },
        });
        // Unknown and foreign ticket identities have the same result.
        if (!ticket) throw new NotFoundException('Tiket tidak ditemukan');

        const date = ticket.tanggalAntrean.toISOString().slice(0, 10);
        const sameDay = date === today.tanggal;
        const room = ticket.loket;
        const result: TiketDispatch = {
          versiSkema: 1,
          tiketId: ticket.id,
          status: ticket.status,
          tanggalPelayanan: date,
          diperolehPada: now.toISOString(),
          checkInPada: ticket.checkInPada?.toISOString() ?? null,
          layanan: {
            id: ticket.layanan.id,
            kode: ticket.layanan.kode,
            nama: ticket.layanan.nama,
            modeReservasi: ticket.layanan.modeReservasi,
          },
          // Before CALL this foreign key is the check-in room, not a promised
          // destination: the daily queue is shared by every eligible service room.
          loketTujuan:
            room?.aktif &&
            room.layananId === ticket.layananId &&
            (ticket.status === StatusTiket.DIPANGGIL ||
              ticket.status === StatusTiket.DILAYANI)
              ? { id: room.id, kode: room.kode, nama: room.nama }
              : null,
          posisiAntrean: null,
          jumlahDiDepan: null,
          alasanPosisi: null,
          sedangDilayani: [],
        };

        if (sameDay && ticket.layanan.aktif) {
          const serving = await tx.tiketAntrean.findMany({
            where: {
              layananId: ticket.layananId,
              tanggalAntrean: today.tanggalDb,
              status: StatusTiket.DILAYANI,
              checkInPada: { not: null },
              loket: { is: { aktif: true, layananId: ticket.layananId } },
            },
            select: {
              nomorUrut: true,
              loket: { select: { id: true, kode: true } },
            },
            orderBy: [{ loketId: 'asc' }, { id: 'asc' }],
          });
          result.sedangDilayani = serving.flatMap((entry) =>
            entry.loket
              ? [
                  {
                    loketId: entry.loket.id,
                    kodeLoket: entry.loket.kode,
                    nomorAntrean: `${ticket.layanan.prefixAntrean.trim()}-${String(entry.nomorUrut).padStart(3, '0')}`,
                  },
                ]
              : [],
          );
        }

        if (ticket.layanan.modeReservasi !== ModeReservasi.ANTREAN_HARIAN) {
          result.alasanPosisi = 'MODE_ANTREAN_BELUM_DIDUKUNG';
        } else if (ticket.status !== StatusTiket.MENUNGGU) {
          result.alasanPosisi = 'STATUS_BUKAN_MENUNGGU';
        } else if (!sameDay) {
          result.alasanPosisi = 'BUKAN_HARI_PELAYANAN';
        } else if (!ticket.layanan.aktif) {
          result.alasanPosisi = 'LAYANAN_TIDAK_AKTIF';
        } else if (
          ticket.checkInPada === null ||
          ticket.urutanMasukAntrean === null
        ) {
          result.alasanPosisi = 'BELUM_MASUK_ANTREAN';
        } else {
          const schedule = await tx.jadwalLayanan.findUnique({
            where: {
              layananId_hari: { layananId: ticket.layananId, hari: today.hari },
            },
            select: { aktif: true },
          });
          if (!schedule?.aktif) {
            result.alasanPosisi = 'JADWAL_LAYANAN_TIDAK_AKTIF';
            return result;
          }
          // Do not require a room to be idle: its active service finishes before
          // the next waiting patient, and is displayed separately above.
          const availableRoom = await tx.loket.findFirst({
            where: {
              layananId: ticket.layananId,
              aktif: true,
              penugasanPetugas: {
                some: {
                  aktif: true,
                  tanggalMulai: { lte: today.tanggalDb },
                  OR: [
                    { tanggalSelesai: null },
                    { tanggalSelesai: { gte: today.tanggalDb } },
                  ],
                  petugas: {
                    is: { aktif: true, peran: PeranPengguna.PETUGAS },
                  },
                },
              },
            },
            select: { id: true },
          });
          if (!availableRoom) {
            result.alasanPosisi = 'LOKET_PELAYANAN_BELUM_TERSEDIA';
            return result;
          }
          const ahead = await tx.tiketAntrean.count({
            where: {
              layananId: ticket.layananId,
              tanggalAntrean: today.tanggalDb,
              status: StatusTiket.MENUNGGU,
              urutanMasukAntrean: { not: null },
              OR: [
                { urutanMasukAntrean: { lt: ticket.urutanMasukAntrean } },
                {
                  urutanMasukAntrean: ticket.urutanMasukAntrean,
                  id: { lt: ticket.id },
                },
              ],
            },
          });
          result.posisiAntrean = ahead + 1;
          result.jumlahDiDepan = ahead;
        }
        return result;
      },
      {
        isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead,
        maxWait: 3000,
        timeout: 10000,
      },
    );
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
