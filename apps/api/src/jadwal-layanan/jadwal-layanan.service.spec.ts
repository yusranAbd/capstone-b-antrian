import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { HariLayanan, PeranPengguna, Prisma } from '../generated/prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { JadwalLayananService } from './jadwal-layanan.service';

// ==========================================
// DATA PENGUJIAN
// ==========================================

const layananId = '1bfa9aa4-6c27-4e67-b938-b0fb53f485cf';

const layananLainId = '64bc924c-b4d3-48ae-be01-f933b5efe555';

const jadwalId = '317ea6bf-367c-41f0-b1c8-2ea151b13195';

const jam0800 = new Date('1970-01-01T08:00:00.000Z');

const jam1200 = new Date('1970-01-01T12:00:00.000Z');

const jam1400 = new Date('1970-01-01T14:00:00.000Z');

const layananUji = {
  id: layananId,
  kode: 'ADM',
  nama: 'Layanan Administrasi Umum',
  aktif: true,
};

const jadwalUji = {
  id: jadwalId,
  layananId,
  hari: HariLayanan.SABTU,
  jamBuka: jam0800,
  jamTutup: jam1200,
  kapasitasHarian: 50,
  aktif: true,
  dibuatPada: new Date('2026-10-09T01:49:18.689Z'),
  diperbaruiPada: new Date('2026-10-09T01:49:18.689Z'),
  layanan: layananUji,
};

const jadwalNonaktif = {
  ...jadwalUji,
  aktif: false,
};

const dataCreate = {
  layananId,
  hari: HariLayanan.SABTU,
  jamBuka: '08:00',
  jamTutup: '12:00',
  kapasitasHarian: 50,
};

// ==========================================
// MOCK PRISMA
// ==========================================

const buatPrismaMock = () => ({
  layanan: {
    findUnique: jest.fn(),
  },

  jadwalLayanan: {
    create: jest.fn(),
    findMany: jest.fn(),
    findFirst: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
  },
});

// ==========================================
// SIMULASI ERROR PRISMA
// ==========================================

function buatErrorPrisma(kode: string): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('Simulasi kesalahan Prisma', {
    code: kode,
    clientVersion: '7.10.0',
  });
}

// ==========================================
// UNIT TEST JADWAL LAYANAN
// ==========================================

describe('JadwalLayananService', () => {
  let service: JadwalLayananService;
  let prismaMock: ReturnType<typeof buatPrismaMock>;

  beforeEach(async () => {
    prismaMock = buatPrismaMock();

    const moduleRef = await Test.createTestingModule({
      providers: [
        JadwalLayananService,
        {
          provide: PrismaService,
          useValue: prismaMock,
        },
      ],
    }).compile();

    service = moduleRef.get<JadwalLayananService>(JadwalLayananService);
  });

  // ========================================
  // 1. CREATE JADWAL
  // ========================================

  describe('Create Jadwal', () => {
    it('berhasil membuat jadwal pada layanan aktif', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue(layananUji);

      prismaMock.jadwalLayanan.create.mockResolvedValue(jadwalUji);

      const hasil = await service.create(dataCreate);

      expect(hasil).toEqual(jadwalUji);

      expect(prismaMock.layanan.findUnique).toHaveBeenCalledWith({
        where: {
          id: layananId,
        },
        select: {
          id: true,
          aktif: true,
        },
      });

      expect(prismaMock.jadwalLayanan.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: {
            hari: HariLayanan.SABTU,
            jamBuka: jam0800,
            jamTutup: jam1200,
            kapasitasHarian: 50,
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

    it('menolak jam tutup yang lebih awal daripada jam buka', async () => {
      await expect(
        service.create({
          ...dataCreate,
          jamBuka: '15:00',
          jamTutup: '08:00',
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prismaMock.jadwalLayanan.create).not.toHaveBeenCalled();
    });

    it('menolak create jika layanan tidak ditemukan', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue(null);

      await expect(service.create(dataCreate)).rejects.toThrow(
        NotFoundException,
      );

      expect(prismaMock.jadwalLayanan.create).not.toHaveBeenCalled();
    });

    it('menolak create jika layanan tidak aktif', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue({
        ...layananUji,
        aktif: false,
      });

      await expect(service.create(dataCreate)).rejects.toThrow(
        BadRequestException,
      );

      expect(prismaMock.jadwalLayanan.create).not.toHaveBeenCalled();
    });

    it('menolak jadwal duplikat pada layanan dan hari yang sama', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue(layananUji);

      prismaMock.jadwalLayanan.create.mockRejectedValue(
        buatErrorPrisma('P2002'),
      );

      await expect(service.create(dataCreate)).rejects.toThrow(
        ConflictException,
      );
    });

    it('menangani kesalahan relasi database', async () => {
      prismaMock.layanan.findUnique.mockResolvedValue(layananUji);

      prismaMock.jadwalLayanan.create.mockRejectedValue(
        buatErrorPrisma('P2003'),
      );

      await expect(service.create(dataCreate)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  // ========================================
  // 2. READ ALL JADWAL
  // ========================================

  describe('Read All Jadwal', () => {
    it('ADMIN dapat melihat jadwal aktif dan nonaktif', async () => {
      prismaMock.jadwalLayanan.findMany.mockResolvedValue([
        jadwalUji,
        jadwalNonaktif,
      ]);

      const hasil = await service.findAll(PeranPengguna.ADMIN);

      expect(hasil).toHaveLength(2);

      expect(prismaMock.jadwalLayanan.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {},
        }),
      );
    });

    it('USER hanya dapat melihat jadwal aktif pada layanan aktif', async () => {
      prismaMock.jadwalLayanan.findMany.mockResolvedValue([jadwalUji]);

      const hasil = await service.findAll(PeranPengguna.USER);

      expect(hasil).toHaveLength(1);

      expect(prismaMock.jadwalLayanan.findMany).toHaveBeenCalledWith(
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

    it('PETUGAS hanya dapat melihat jadwal aktif', async () => {
      prismaMock.jadwalLayanan.findMany.mockResolvedValue([jadwalUji]);

      await service.findAll(PeranPengguna.PETUGAS);

      expect(prismaMock.jadwalLayanan.findMany).toHaveBeenCalledWith(
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
  // 3. READ ONE JADWAL
  // ========================================

  describe('Read One Jadwal', () => {
    it('ADMIN dapat melihat jadwal nonaktif', async () => {
      prismaMock.jadwalLayanan.findFirst.mockResolvedValue(jadwalNonaktif);

      const hasil = await service.findOne(jadwalId, PeranPengguna.ADMIN);

      expect(hasil.aktif).toBe(false);

      expect(prismaMock.jadwalLayanan.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: jadwalId,
          },
        }),
      );
    });

    it('USER hanya dapat membuka jadwal aktif', async () => {
      prismaMock.jadwalLayanan.findFirst.mockResolvedValue(jadwalUji);

      const hasil = await service.findOne(jadwalId, PeranPengguna.USER);

      expect(hasil).toEqual(jadwalUji);

      expect(prismaMock.jadwalLayanan.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: jadwalId,
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

    it('menolak jadwal yang tidak ditemukan', async () => {
      prismaMock.jadwalLayanan.findFirst.mockResolvedValue(null);

      await expect(
        service.findOne(jadwalId, PeranPengguna.USER),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // ========================================
  // 4. UPDATE JADWAL
  // ========================================

  describe('Update Jadwal', () => {
    it('berhasil mengubah jam tutup dan kapasitas', async () => {
      prismaMock.jadwalLayanan.findUnique.mockResolvedValue({
        id: jadwalId,
        layananId,
        jamBuka: jam0800,
        jamTutup: jam1200,
      });

      const jadwalDiperbarui = {
        ...jadwalUji,
        jamTutup: jam1400,
        kapasitasHarian: 75,
      };

      prismaMock.jadwalLayanan.update.mockResolvedValue(jadwalDiperbarui);

      const hasil = await service.update(jadwalId, {
        jamTutup: '14:00',
        kapasitasHarian: 75,
      });

      expect(hasil.jamTutup).toEqual(jam1400);
      expect(hasil.kapasitasHarian).toBe(75);

      expect(prismaMock.jadwalLayanan.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: jadwalId,
          },
          data: expect.objectContaining({
            jamTutup: jam1400,
            kapasitasHarian: 75,
          }),
        }),
      );
    });

    it('menolak update jam buka yang melewati jam tutup', async () => {
      prismaMock.jadwalLayanan.findUnique.mockResolvedValue({
        id: jadwalId,
        layananId,
        jamBuka: jam0800,
        jamTutup: jam1200,
      });

      await expect(
        service.update(jadwalId, {
          jamBuka: '15:00',
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prismaMock.jadwalLayanan.update).not.toHaveBeenCalled();
    });

    it('berhasil memindahkan jadwal ke layanan aktif lain', async () => {
      prismaMock.jadwalLayanan.findUnique.mockResolvedValue({
        id: jadwalId,
        layananId,
        jamBuka: jam0800,
        jamTutup: jam1200,
      });

      prismaMock.layanan.findUnique.mockResolvedValue({
        id: layananLainId,
        aktif: true,
      });

      prismaMock.jadwalLayanan.update.mockResolvedValue({
        ...jadwalUji,
        layananId: layananLainId,
      });

      const hasil = await service.update(jadwalId, {
        layananId: layananLainId,
      });

      expect(hasil.layananId).toBe(layananLainId);

      expect(prismaMock.layanan.findUnique).toHaveBeenCalledWith({
        where: {
          id: layananLainId,
        },
        select: {
          id: true,
          aktif: true,
        },
      });

      expect(prismaMock.jadwalLayanan.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            layanan: {
              connect: {
                id: layananLainId,
              },
            },
          }),
        }),
      );
    });

    it('menolak reaktivasi jika layanan induk tidak aktif', async () => {
      prismaMock.jadwalLayanan.findUnique.mockResolvedValue({
        id: jadwalId,
        layananId,
        jamBuka: jam0800,
        jamTutup: jam1200,
      });

      prismaMock.layanan.findUnique.mockResolvedValue({
        ...layananUji,
        aktif: false,
      });

      await expect(
        service.update(jadwalId, {
          aktif: true,
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prismaMock.jadwalLayanan.update).not.toHaveBeenCalled();
    });

    it('menolak update jika jadwal tidak ditemukan', async () => {
      prismaMock.jadwalLayanan.findUnique.mockResolvedValue(null);

      await expect(
        service.update(jadwalId, {
          kapasitasHarian: 120,
        }),
      ).rejects.toThrow(NotFoundException);

      expect(prismaMock.jadwalLayanan.update).not.toHaveBeenCalled();
    });

    it('menolak perubahan yang menyebabkan jadwal duplikat', async () => {
      prismaMock.jadwalLayanan.findUnique.mockResolvedValue({
        id: jadwalId,
        layananId,
        jamBuka: jam0800,
        jamTutup: jam1200,
      });

      prismaMock.jadwalLayanan.update.mockRejectedValue(
        buatErrorPrisma('P2002'),
      );

      await expect(
        service.update(jadwalId, {
          hari: HariLayanan.SENIN,
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ========================================
  // 5. SOFT DELETE
  // ========================================

  describe('Soft Delete Jadwal', () => {
    it('berhasil menonaktifkan jadwal tanpa menghapus data', async () => {
      prismaMock.jadwalLayanan.update.mockResolvedValue(jadwalNonaktif);

      const hasil = await service.remove(jadwalId);

      expect(hasil.aktif).toBe(false);

      expect(prismaMock.jadwalLayanan.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            id: jadwalId,
          },
          data: {
            aktif: false,
          },
        }),
      );
    });

    it('menolak soft delete jika jadwal tidak ditemukan', async () => {
      prismaMock.jadwalLayanan.update.mockRejectedValue(
        buatErrorPrisma('P2025'),
      );

      await expect(service.remove(jadwalId)).rejects.toThrow(NotFoundException);
    });
  });
});
