import { Injectable } from '@nestjs/common';
import { ModeReservasi, PeranPengguna } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { waktuPelayanan } from '../hospital/hospital-context';

/** Configuration hints only; booking/queue authorization stays in its engine. */
@Injectable()
export class LayananReadinessService {
  constructor(private readonly prisma: PrismaService) {}

  async snapshot() {
    const now = new Date();
    const { tanggal, tanggalDb: today } = waktuPelayanan(now);
    const services = await this.prisma.layanan.findMany({
      orderBy: { nama: 'asc' },
      include: {
        jadwalLayanan: { where: { aktif: true } },
        loket: {
          where: { aktif: true },
          include: {
            penugasanPetugas: {
              where: {
                aktif: true,
                tanggalMulai: { lte: today },
                OR: [
                  { tanggalSelesai: null },
                  { tanggalSelesai: { gte: today } },
                ],
                petugas: { aktif: true, peran: PeranPengguna.PETUGAS },
              },
              select: { id: true },
              take: 1,
            },
          },
        },
        dokterLayanan: {
          where: { aktif: true, dokter: { aktif: true } },
          include: {
            jadwalPraktik: {
              where: {
                aktif: true,
                tanggal: { gte: today },
                selesaiPada: { gt: now },
                loket: { aktif: true },
              },
              include: {
                slotPraktik: {
                  where: {
                    aktif: true,
                    kapasitas: { gt: 0 },
                    selesaiPada: { gt: now },
                  },
                  select: { mulaiPada: true, selesaiPada: true },
                },
              },
            },
          },
        },
      },
    });
    return services.map((service) => {
      const kekurangan: string[] = [];
      if (!service.aktif) kekurangan.push('Layanan belum aktif.');
      if (!service.loket.length)
        kekurangan.push('Belum ada ruang/loket aktif.');
      if (
        !service.jadwalLayanan.some(
          (h) => h.kapasitasHarian > 0 && h.jamTutup > h.jamBuka,
        )
      ) {
        kekurangan.push(
          'Jam layanan dan kapasitas harian aktif belum tersedia.',
        );
      }
      for (const room of service.loket) {
        if (!room.penugasanPetugas.length)
          kekurangan.push(
            `Ruang ${room.nama} belum memiliki petugas aktif yang ditugaskan hari ini.`,
          );
      }
      if (service.modeReservasi !== ModeReservasi.ANTREAN_HARIAN) {
        if (!service.dokterLayanan.length)
          kekurangan.push('Belum ada dokter aktif yang terhubung.');
        const sessions = service.dokterLayanan
          .flatMap((d) => d.jadwalPraktik)
          .filter(
            (s) =>
              service.loket.some((r) => r.id === s.loketId) &&
              s.mulaiPada < s.selesaiPada &&
              waktuPelayanan(s.mulaiPada).tanggal ===
                s.tanggal.toISOString().slice(0, 10) &&
              waktuPelayanan(s.selesaiPada).tanggal ===
                s.tanggal.toISOString().slice(0, 10) &&
              service.jadwalLayanan.some(
                (hours) =>
                  hours.hari === waktuPelayanan(s.mulaiPada).hari &&
                  hours.kapasitasHarian > 0 &&
                  waktuPelayanan(s.mulaiPada).jam >=
                    hours.jamBuka.toISOString().slice(11, 19) &&
                  waktuPelayanan(s.selesaiPada).jam <=
                    hours.jamTutup.toISOString().slice(11, 19),
              ),
          );
        if (!sessions.length)
          kekurangan.push('Belum ada sesi praktik aktif yang belum berakhir.');
        else if (
          !sessions.some((s) =>
            s.slotPraktik.some(
              (slot) =>
                slot.mulaiPada >= s.mulaiPada &&
                slot.selesaiPada <= s.selesaiPada &&
                slot.mulaiPada < slot.selesaiPada,
            ),
          )
        ) {
          kekurangan.push(
            'Sesi praktik belum memiliki slot konsultasi aktif yang valid dan belum berakhir.',
          );
        }
      }
      return {
        layananId: service.id,
        tanggalPenilaian: tanggal,
        diperolehPada: now.toISOString(),
        lengkap: !kekurangan.length,
        kekurangan,
      };
    });
  }
}
