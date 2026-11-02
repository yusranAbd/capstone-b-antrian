import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PeranPengguna, Prisma, StatusTiket } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeBroadcastService } from '../realtime/realtime-broadcast.service';
import { BatalkanSesiBerakhirDto } from './dto/batalkan-sesi-berakhir.dto';
import { waktuPelayanan } from '../hospital/hospital-context';

/** Deliberate staff resolution, never an automatic expiry or queue priority change. */
@Injectable()
export class QueueResolutionService {
  private readonly logger = new Logger(QueueResolutionService.name);
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeBroadcastService,
  ) {}

  async batalkan(
    tiketId: string,
    petugasId: string,
    dto: BatalkanSesiBerakhirDto,
  ) {
    const hasil = await this.transaksi(async (tx) => {
      const reference = await tx.janjiTemu.findUnique({
        where: { tiketId },
        select: {
          slotPraktikId: true,
          slotPraktik: { select: { jadwalPraktikId: true } },
        },
      });
      if (!reference)
        throw new ConflictException(
          'Tindakan ini hanya untuk tiket janji temu',
        );
      // Same lock order as appointment creation/cancellation and schedule edits.
      await tx.$queryRaw`SELECT 1 FROM pg_advisory_xact_lock(hashtextextended(${`queueb:jadwal:jadwal:${reference.slotPraktik.jadwalPraktikId}`}, 0))`;
      await tx.$queryRaw`SELECT 1 FROM pg_advisory_xact_lock(hashtextextended(${`queueb:slot:${reference.slotPraktikId}`}, 0))`;
      const now = new Date();
      const { tanggalDb: today } = waktuPelayanan(now);
      const [ticket, assignment] = await Promise.all([
        tx.tiketAntrean.findUnique({
          where: { id: tiketId },
          include: {
            layanan: true,
            janjiTemu: {
              include: {
                slotPraktik: {
                  include: {
                    jadwalPraktik: { include: { dokterLayanan: true } },
                  },
                },
              },
            },
          },
        }),
        tx.penugasanPetugas.findFirst({
          where: {
            petugasId,
            loketId: dto.loketId,
            aktif: true,
            tanggalMulai: { lte: today },
            OR: [{ tanggalSelesai: null }, { tanggalSelesai: { gte: today } }],
            petugas: { aktif: true, peran: PeranPengguna.PETUGAS },
            loket: { aktif: true, layanan: { aktif: true } },
          },
          include: { loket: true },
        }),
      ]);
      if (!assignment)
        throw new ForbiddenException(
          'Penugasan petugas tidak berlaku untuk ruang ini',
        );
      if (!ticket) throw new NotFoundException('Tiket tidak ditemukan');
      const session = ticket.janjiTemu?.slotPraktik.jadwalPraktik;
      if (
        !session ||
        session.loketId !== dto.loketId ||
        ticket.layananId !== assignment.loket.layananId ||
        session.dokterLayanan.layananId !== ticket.layananId ||
        (ticket.loketId !== null && ticket.loketId !== dto.loketId)
      ) {
        throw new ForbiddenException('Tiket bukan milik pelayanan ruang ini');
      }
      if (
        ticket.tanggalAntrean.getTime() !== today.getTime() ||
        session.tanggal.getTime() !== today.getTime()
      ) {
        throw new ConflictException(
          'Tindakan hanya berlaku pada tanggal pelayanan hari ini',
        );
      }
      if (ticket.status !== StatusTiket.MENUNGGU || session.selesaiPada > now) {
        throw new ConflictException(
          'Hanya tiket MENUNGGU dengan sesi yang sudah berakhir dapat dibatalkan',
        );
      }
      const updated = await tx.tiketAntrean.updateMany({
        where: {
          id: tiketId,
          status: StatusTiket.MENUNGGU,
          versi: ticket.versi,
        },
        data: {
          status: StatusTiket.DIBATALKAN,
          versi: { increment: 1 },
          tokenQrHash: null,
          qrKedaluwarsaPada: null,
        },
      });
      if (updated.count !== 1)
        throw new ConflictException('Status tiket telah berubah');
      await tx.peristiwaAntrean.create({
        data: {
          tiketAntreanId: tiketId,
          aktorId: petugasId,
          tipe: 'CANCEL_SESSION_ENDED',
          statusSebelum: StatusTiket.MENUNGGU,
          statusSesudah: StatusTiket.DIBATALKAN,
          versi: ticket.versi + 1,
          dataTambahan: {
            alasan: dto.alasan,
            loketId: dto.loketId,
            penugasanId: assignment.id,
            jadwalPraktikId: session.id,
            slotPraktikId: reference.slotPraktikId,
          },
        },
      });
      return {
        tiketId,
        layananId: ticket.layananId,
        loketId: dto.loketId,
        kodeLoket: assignment.loket.kode,
        nomorAntrean: `${ticket.layanan.prefixAntrean.trim()}-${String(ticket.nomorUrut).padStart(3, '0')}`,
        status: StatusTiket.DIBATALKAN,
        versi: ticket.versi + 1,
        urutanMasukAntrean: ticket.urutanMasukAntrean,
      };
    });
    try {
      await this.realtime.kirim({ ...hasil, aksi: 'CANCEL' });
    } catch {
      this.logger.warn(
        'Invalidasi pembatalan gagal; transaksi tetap tersimpan',
      );
    }
    return hasil;
  }

  private async transaksi<T>(
    run: (tx: Prisma.TransactionClient) => Promise<T>,
  ): Promise<T> {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        return await this.prisma.$transaction(run, {
          isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
          maxWait: 10000,
          timeout: 15000,
        });
      } catch (error) {
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2034'
        ) {
          if (attempt < 2) continue;
          throw new ConflictException(
            'Antrean berubah bersamaan. Muat ulang antrean',
          );
        }
        throw error;
      }
    }
    throw new ConflictException('Pembatalan belum dapat diproses');
  }
}
