import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const select = {
  id: true,
  tiketAntreanId: true,
  jenis: true,
  judul: true,
  pesan: true,
  dibacaPada: true,
  dibuatPada: true,
} as const;
@Injectable()
export class NotifikasiService {
  constructor(private readonly prisma: PrismaService) {}
  async list(penggunaId: string, halaman = 1) {
    return this.prisma.$transaction(
      async (tx) => {
        const [total, belumDibaca, data] = await Promise.all([
          tx.notifikasi.count({ where: { penggunaId } }),
          tx.notifikasi.count({ where: { penggunaId, dibacaPada: null } }),
          tx.notifikasi.findMany({
            where: { penggunaId },
            select,
            orderBy: [{ dibuatPada: 'desc' }, { id: 'desc' }],
            skip: (halaman - 1) * 20,
            take: 20,
          }),
        ]);
        return {
          total,
          belumDibaca,
          halaman,
          jumlahHalaman: Math.max(1, Math.ceil(total / 20)),
          data,
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }
  async read(penggunaId: string, id: string) {
    await this.prisma.notifikasi.updateMany({
      where: { id, penggunaId, dibacaPada: null },
      data: { dibacaPada: new Date() },
    });
    const row = await this.prisma.notifikasi.findFirst({
      where: { id, penggunaId },
      select,
    });
    if (!row) throw new NotFoundException('Notifikasi tidak ditemukan');
    return row;
  }
}
