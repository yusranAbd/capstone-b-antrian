import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { createHash, randomBytes } from 'node:crypto';

import { StatusTiket } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const MASA_BERLAKU_QR_MENIT = 10;

@Injectable()
export class QrService {
  constructor(private readonly prisma: PrismaService) {}

  // ==========================================
  // PENERBITAN TOKEN QR
  // ==========================================

  async terbitkan(tiketId: string, penggunaId: string) {
    // 1. Pastikan tiket milik pengguna.
    const tiket = await this.prisma.tiketAntrean.findFirst({
      where: {
        id: tiketId,
        penggunaId,
      },
      select: {
        id: true,
        penggunaId: true,
        tanggalAntrean: true,
        status: true,
        versi: true,
      },
    });

    if (!tiket) {
      throw new NotFoundException('Tiket tidak ditemukan');
    }

    // 2. Hanya tiket DIPESAN yang dapat
    // menerbitkan QR Check-In.
    if (tiket.status !== StatusTiket.DIPESAN) {
      throw new ConflictException(
        'QR hanya dapat diterbitkan untuk tiket berstatus DIPESAN',
      );
    }

    // 3. Tolak tiket dengan tanggal
    // pelayanan yang sudah lewat.
    const tanggalPelayanan = tiket.tanggalAntrean.toISOString().slice(0, 10);

    const hariIni = this.tanggalHariIniLokal();

    if (tanggalPelayanan !== hariIni) {
      throw new BadRequestException(
        'QR hanya dapat diterbitkan pada tanggal pelayanan',
      );
    }

    // 4. Buat token acak 256-bit.
    // Nilai asli hanya dikirim pada respons
    // penerbitan dan tidak disimpan di DB.
    const token = randomBytes(32).toString('base64url');

    // Format QR hanya berisi versi payload
    // dan token acak, tanpa data pribadi.
    const qrPayload = `SQ1.${token}`;

    // 5. Simpan hanya hash SHA-256.
    const tokenQrHash = createHash('sha256')
      .update(qrPayload, 'utf8')
      .digest('hex');

    // 6. Hitung masa berlaku QR.
    const sekarang = new Date();

    const qrKedaluwarsaPada = new Date(
      sekarang.getTime() + MASA_BERLAKU_QR_MENIT * 60 * 1000,
    );

    // 7. Update atomik menggunakan versi.
    // Jika ada perubahan serentak,
    // salah satu request ditolak.
    const hasil = await this.prisma.tiketAntrean.updateMany({
      where: {
        id: tiket.id,
        penggunaId,
        status: StatusTiket.DIPESAN,
        versi: tiket.versi,
      },
      data: {
        tokenQrHash,
        qrKedaluwarsaPada,
        versi: {
          increment: 1,
        },
      },
    });

    if (hasil.count !== 1) {
      throw new ConflictException(
        'Tiket sedang diperbarui. Silakan coba kembali',
      );
    }

    // 8. Kembalikan QR payload,
    // tetapi jangan pernah mengembalikan hash.
    return {
      tiketId: tiket.id,
      qrPayload,
      berlakuHingga: qrKedaluwarsaPada.toISOString(),
      masaBerlakuDetik: MASA_BERLAKU_QR_MENIT * 60,
      status: StatusTiket.DIPESAN,
    };
  }

  // ==========================================
  // ZONA WAKTU PELAYANAN
  // ==========================================

  private tanggalHariIniLokal(): string {
    const zonaWaktu = process.env.SERVICE_TIME_ZONE ?? 'Asia/Jakarta';

    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: zonaWaktu,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });

    const bagian = formatter.formatToParts(new Date());

    const ambil = (tipe: string): string =>
      bagian.find((item) => item.type === tipe)?.value ?? '';

    return [ambil('year'), ambil('month'), ambil('day')].join('-');
  }
}
