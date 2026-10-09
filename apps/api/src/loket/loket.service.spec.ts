import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { PeranPengguna, Prisma } from '../generated/prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { LoketService } from './loket.service';

// ==========================================
// DATA PENGUJIAN
// ==========================================

const layananId = '1bfa9aa4-6c27-4e67-b938-b0fb53f485cf';

const loketId = '09715e8d-db13-4181-9b48-a9382d8e85e2';

const layananUji = {
  id: layananId,
  kode: 'ADM',
  nama: 'Layanan Administrasi Umum',
  aktif: true,
};

const loketUji = {
  id: loketId,
  layananId,
  kode: 'LKT-A2',
  nama: 'Loket Administrasi 2',
  lokasi: 'Ruang Pelayanan',
  aktif: true,
  dibuatPada: new Date('2026-10-09T00:01:34.494Z'),
  diperbaruiPada: new Date('2026-10-09T00:01:34.494Z'),
  layanan: layananUji,
};

const loketNonaktif = {
  ...loketUji,
  aktif: false,
};

const dataCreate = {
  layananId,
  kode: 'LKT-A2',
  nama: 'Loket Administrasi 2',
  lokasi: 'Ruang Pelayanan',
};

// ==========================================
// MOCK PRISMA
// ==========================================

const buatPrismaMock = () => ({
  layanan: {
    findUnique: jest.fn(),
  },

  loket: {
    create: jest.fn(),
    findMany: jest.fn(),
    findFirst: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
  },
});

// ==========================================
// HELPER ERROR PRISMA
// ==========================================

function buatErrorPrisma(kode: string): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('Simulasi kesalahan Prisma', {
    code: kode,
    clientVersion: '7.10.0',
  });
}

// ==========================================
// LOKET SERVICE TEST
// ==========================================

describe('LoketService', () => {
  let service: LoketService;
  let prismaMock: ReturnType<typeof buatPrismaMock>;

  beforeEach(async () => {
    prismaMock = buatPrismaMock();

    const moduleRef = await Test.createTestingModule({
      providers: [
        LoketService,
        {
          provide: PrismaService,
          useValue: prismaMock,
        },
      ],
    }).compile();

    service = moduleRef.get<LoketService>(LoketService);
  });

  // ========================================
  // 1. CREATE LOKET
  // ========================================

  describe('Create Loket', () => {
    it('berhasil membuat loket pada layanan aktif', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue(layananUji);

      prismaMock.loket.create.mockResolvedValue(loketUji);

      const hasil = await service.create(dataCreate);

      expect(hasil).toEqual(loketUji);

      expect(prismaMock.layanan.findUnique).toHaveBeenCalledWith({
        where: {
          id: layananId,
        },
        select: {
          id: true,
          aktif: true,
        },
      });

      expect(prismaMock.loket.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: {
            kode: 'LKT-A2',
            nama: 'Loket Administrasi 2',
            lokasi: 'Ruang Pelayanan',
            aktif: true,
            layanan: {
              connect: {
                id: layananId,
              },
            },
          },
        }),
      );
    });

    it('menolak create jika layanan tidak ditemukan', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue(null);

      await expect(service.create(dataCreate)).rejects.toThrow(
        NotFoundException,
      );

      expect(prismaMock.loket.create).not.toHaveBeenCalled();
    });

    it('menolak create jika layanan tidak aktif', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue({
        ...layananUji,
        aktif: false,
      });

      await expect(service.create(dataCreate)).rejects.toThrow(
        BadRequestException,
      );

      expect(prismaMock.loket.create).not.toHaveBeenCalled();
    });

    it('menolak kode loket duplikat pada layanan yang sama', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue(layananUji);

      prismaMock.loket.create.mockRejectedValue(buatErrorPrisma('P2002'));

      await expect(service.create(dataCreate)).rejects.toThrow(
        ConflictException,
      );
    });

    it('menangani kesalahan relasi database', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue(layananUji);

      prismaMock.loket.create.mockRejectedValue(buatErrorPrisma('P2003'));

      await expect(service.create(dataCreate)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  // ========================================
  // 2. READ ALL LOKET
  // ========================================

  describe('Read All Loket', () => {
    it('ADMIN melihat loket aktif dan nonaktif', async () => {
      prismaMock.loket.findMany.mockResolvedValue([loketUji, loketNonaktif]);

      const hasil = await service.findAll(PeranPengguna.ADMIN);

      expect(hasil).toHaveLength(2);

      expect(prismaMock.loket.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {},
        }),
      );
    });

    it('USER hanya melihat loket dari layanan aktif', async () => {
      prismaMock.loket.findMany.mockResolvedValue([loketUji]);

      const hasil = await service.findAll(PeranPengguna.USER);

      expect(hasil).toHaveLength(1);

      expect(prismaMock.loket.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            aktif: true,
            layanan: {
              is: {
                aktif: true,
              },
            },
          },
        }),
      );
    });

    it('PETUGAS hanya melihat loket aktif', async () => {
      prismaMock.loket.findMany.mockResolvedValue([loketUji]);

      await service.findAll(PeranPengguna.PETUGAS);

      expect(prismaMock.loket.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            aktif: true,
            layanan: {
              is: {
                aktif: true,
              },
            },
          },
        }),
      );
    });
  });

  // ========================================
  // 3. READ ONE LOKET
  // ========================================

  describe('Read One Loket', () => {
    it('ADMIN dapat melihat loket nonaktif', async () => {
      prismaMock.loket.findFirst.mockResolvedValue(loketNonaktif);

      const hasil = await service.findOne(loketId, PeranPengguna.ADMIN);

      expect(hasil.aktif).toBe(false);

      expect(prismaMock.loket.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: loketId,
          },
        }),
      );
    });

    it('USER hanya dapat membuka loket aktif', async () => {
      prismaMock.loket.findFirst.mockResolvedValue(loketUji);

      const hasil = await service.findOne(loketId, PeranPengguna.USER);

      expect(hasil).toEqual(loketUji);

      expect(prismaMock.loket.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: loketId,
            aktif: true,
            layanan: {
              is: {
                aktif: true,
              },
            },
          },
        }),
      );
    });

    it('menolak loket yang tidak ditemukan', async () => {
      prismaMock.loket.findFirst.mockResolvedValue(null);

      await expect(
        service.findOne(loketId, PeranPengguna.USER),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // ========================================
  // 4. UPDATE LOKET
  // ========================================

  describe('Update Loket', () => {
    it('berhasil memperbarui nama dan lokasi', async () => {
      prismaMock.loket.findUnique.mockResolvedValue({
        id: loketId,
        layananId,
      });

      prismaMock.loket.update.mockResolvedValue({
        ...loketUji,
        nama: 'Loket Administrasi Utama 2',
        lokasi: 'Ruang Pelayanan Lantai 1',
      });

      const hasil = await service.update(loketId, {
        nama: 'Loket Administrasi Utama 2',
        lokasi: 'Ruang Pelayanan Lantai 1',
      });

      expect(hasil.nama).toBe('Loket Administrasi Utama 2');

      expect(hasil.lokasi).toBe('Ruang Pelayanan Lantai 1');

      expect(prismaMock.loket.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: loketId,
          },
          data: expect.objectContaining({
            nama: 'Loket Administrasi Utama 2',
            lokasi: 'Ruang Pelayanan Lantai 1',
          }),
        }),
      );
    });

    it('berhasil memindahkan loket ke layanan aktif lain', async () => {
      const layananBaruId = '64bc924c-b4d3-48ae-be01-f933b5efe555';

      prismaMock.loket.findUnique.mockResolvedValue({
        id: loketId,
        layananId,
      });

      prismaMock.layanan.findUnique.mockResolvedValue({
        id: layananBaruId,
        aktif: true,
      });

      prismaMock.loket.update.mockResolvedValue({
        ...loketUji,
        layananId: layananBaruId,
      });

      const hasil = await service.update(loketId, {
        layananId: layananBaruId,
      });

      expect(hasil.layananId).toBe(layananBaruId);

      expect(prismaMock.layanan.findUnique).toHaveBeenCalledWith({
        where: {
          id: layananBaruId,
        },
        select: {
          id: true,
          aktif: true,
        },
      });

      expect(prismaMock.loket.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            layanan: {
              connect: {
                id: layananBaruId,
              },
            },
          }),
        }),
      );
    });

    it('menolak update jika loket tidak ditemukan', async () => {
      prismaMock.loket.findUnique.mockResolvedValue(null);

      await expect(
        service.update(loketId, {
          nama: 'Nama Baru',
        }),
      ).rejects.toThrow(NotFoundException);

      expect(prismaMock.loket.update).not.toHaveBeenCalled();
    });

    it('menolak kode loket duplikat saat update', async () => {
      prismaMock.loket.findUnique.mockResolvedValue({
        id: loketId,
        layananId,
      });

      prismaMock.loket.update.mockRejectedValue(buatErrorPrisma('P2002'));

      await expect(
        service.update(loketId, {
          kode: 'LKT-A1',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('menolak reaktivasi jika layanan tidak aktif', async () => {
      prismaMock.loket.findUnique.mockResolvedValue({
        id: loketId,
        layananId,
      });

      prismaMock.layanan.findUnique.mockResolvedValue({
        ...layananUji,
        aktif: false,
      });

      await expect(
        service.update(loketId, {
          aktif: true,
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prismaMock.loket.update).not.toHaveBeenCalled();
    });
  });

  // ========================================
  // 5. SOFT DELETE
  // ========================================

  describe('Soft Delete Loket', () => {
    it('berhasil menonaktifkan tanpa menghapus data', async () => {
      prismaMock.loket.update.mockResolvedValue(loketNonaktif);

      const hasil = await service.remove(loketId);

      expect(hasil.aktif).toBe(false);

      expect(prismaMock.loket.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: loketId,
          },
          data: {
            aktif: false,
          },
        }),
      );
    });

    it('menolak soft delete jika loket tidak ditemukan', async () => {
      prismaMock.loket.update.mockRejectedValue(buatErrorPrisma('P2025'));

      await expect(service.remove(loketId)).rejects.toThrow(NotFoundException);
    });
  });
});
