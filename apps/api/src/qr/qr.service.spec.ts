import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';

import { StatusTiket } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { QrService } from './qr.service';

const SEKARANG = new Date('2026-10-10T02:30:00.000Z');

const tiketId = '1a33984d-d5f1-4fdb-b888-545a2c5be9c8';

const penggunaId = 'ec8a387e-f186-4324-8c6a-faec174ce55c';

const penggunaLainId = '00000000-0000-4000-8000-000000000002';

const tiketUji = {
  id: tiketId,
  penggunaId,
  tanggalAntrean: new Date('2026-10-10T00:00:00.000Z'),
  status: StatusTiket.DIPESAN,
  versi: 1,
};

const buatPrismaMock = () => ({
  tiketAntrean: {
    findFirst: jest.fn(),
    updateMany: jest.fn(),
  },
});

describe('QrService', () => {
  let service: QrService;
  let prismaMock: ReturnType<typeof buatPrismaMock>;
  let zonaWaktuSebelumnya: string | undefined;

  beforeAll(() => {
    zonaWaktuSebelumnya = process.env.SERVICE_TIME_ZONE;
    process.env.SERVICE_TIME_ZONE = 'Asia/Jakarta';
  });

  afterAll(() => {
    if (zonaWaktuSebelumnya === undefined) {
      delete process.env.SERVICE_TIME_ZONE;
    } else {
      process.env.SERVICE_TIME_ZONE = zonaWaktuSebelumnya;
    }
  });

  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(SEKARANG);

    prismaMock = buatPrismaMock();

    prismaMock.tiketAntrean.findFirst.mockResolvedValue(tiketUji);

    prismaMock.tiketAntrean.updateMany.mockResolvedValue({ count: 1 });

    service = new QrService(prismaMock as unknown as PrismaService);
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  describe('Penerbitan QR', () => {
    it('berhasil menerbitkan token QR dengan format SQ1', async () => {
      const hasil = await service.terbitkan(tiketId, penggunaId);

      expect(hasil.tiketId).toBe(tiketId);

      expect(hasil.qrPayload).toMatch(/^SQ1\.[A-Za-z0-9_-]{43}$/);

      expect(hasil.status).toBe(StatusTiket.DIPESAN);
    });

    it('mencari tiket menggunakan ID dan identitas pemilik', async () => {
      await service.terbitkan(tiketId, penggunaId);

      expect(prismaMock.tiketAntrean.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: tiketId,
            penggunaId,
          },
        }),
      );
    });

    it('menyimpan SHA-256 hash dan bukan token asli', async () => {
      const hasil = await service.terbitkan(tiketId, penggunaId);

      const hashDiharapkan = createHash('sha256')
        .update(hasil.qrPayload, 'utf8')
        .digest('hex');

      const argumen = prismaMock.tiketAntrean.updateMany.mock.calls[0][0] as {
        data: {
          tokenQrHash: string;
        };
      };

      expect(argumen.data.tokenQrHash).toBe(hashDiharapkan);

      expect(argumen.data.tokenQrHash).toMatch(/^[a-f0-9]{64}$/);

      expect(argumen.data.tokenQrHash).not.toBe(hasil.qrPayload);
    });

    it('menghasilkan token dengan masa berlaku 600 detik', async () => {
      const hasil = await service.terbitkan(tiketId, penggunaId);

      expect(hasil.masaBerlakuDetik).toBe(600);

      expect(hasil.berlakuHingga).toBe('2026-10-10T02:40:00.000Z');
    });

    it('menggunakan versi dan status pada update atomik', async () => {
      await service.terbitkan(tiketId, penggunaId);

      expect(prismaMock.tiketAntrean.updateMany).toHaveBeenCalledWith({
        where: {
          id: tiketId,
          penggunaId,
          status: StatusTiket.DIPESAN,
          versi: 1,
        },
        data: {
          tokenQrHash: expect.any(String) as string,
          qrKedaluwarsaPada: new Date('2026-10-10T02:40:00.000Z'),
          versi: {
            increment: 1,
          },
        },
      });
    });

    it('penerbitan ulang menghasilkan token baru', async () => {
      const pertama = await service.terbitkan(tiketId, penggunaId);

      const kedua = await service.terbitkan(tiketId, penggunaId);

      expect(pertama.qrPayload).not.toBe(kedua.qrPayload);

      expect(prismaMock.tiketAntrean.updateMany).toHaveBeenCalledTimes(2);
    });
  });

  describe('Validasi QR', () => {
    it('menolak tiket yang tidak ditemukan', async () => {
      prismaMock.tiketAntrean.findFirst.mockResolvedValue(null);

      await expect(service.terbitkan(tiketId, penggunaId)).rejects.toThrow(
        NotFoundException,
      );

      expect(prismaMock.tiketAntrean.updateMany).not.toHaveBeenCalled();
    });

    it('menolak penerbitan untuk pengguna bukan pemilik', async () => {
      prismaMock.tiketAntrean.findFirst.mockResolvedValue(null);

      await expect(service.terbitkan(tiketId, penggunaLainId)).rejects.toThrow(
        NotFoundException,
      );

      expect(prismaMock.tiketAntrean.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: tiketId,
            penggunaId: penggunaLainId,
          },
        }),
      );
    });

    it('menolak tiket yang sudah CHECK_IN', async () => {
      prismaMock.tiketAntrean.findFirst.mockResolvedValue({
        ...tiketUji,
        status: StatusTiket.CHECK_IN,
      });

      await expect(service.terbitkan(tiketId, penggunaId)).rejects.toThrow(
        ConflictException,
      );
    });

    it('menolak tiket yang DIBATALKAN', async () => {
      prismaMock.tiketAntrean.findFirst.mockResolvedValue({
        ...tiketUji,
        status: StatusTiket.DIBATALKAN,
      });

      await expect(service.terbitkan(tiketId, penggunaId)).rejects.toThrow(
        ConflictException,
      );
    });

    it('menolak QR untuk tanggal pelayanan lampau', async () => {
      prismaMock.tiketAntrean.findFirst.mockResolvedValue({
        ...tiketUji,
        tanggalAntrean: new Date('2026-10-09T00:00:00.000Z'),
      });

      await expect(service.terbitkan(tiketId, penggunaId)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('menolak QR sebelum tanggal pelayanan', async () => {
      prismaMock.tiketAntrean.findFirst.mockResolvedValue({
        ...tiketUji,
        tanggalAntrean: new Date('2026-10-12T00:00:00.000Z'),
      });

      await expect(service.terbitkan(tiketId, penggunaId)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('menolak konflik versi tiket yang telah berubah', async () => {
      prismaMock.tiketAntrean.updateMany.mockResolvedValue({
        count: 0,
      });

      await expect(service.terbitkan(tiketId, penggunaId)).rejects.toThrow(
        ConflictException,
      );
    });

    it('meneruskan gangguan database', async () => {
      prismaMock.tiketAntrean.updateMany.mockRejectedValue(
        new Error('Koneksi database terputus'),
      );

      await expect(service.terbitkan(tiketId, penggunaId)).rejects.toThrow(
        'Koneksi database terputus',
      );
    });
  });
});
