import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { StatusTiket } from '../generated/prisma/client';
import { ReservasiService } from '../reservasi/reservasi.service';

import { TiketService } from './tiket.service';

// ==========================================
// DATA PENGUJIAN
// ==========================================

type DataReservasi = Awaited<ReturnType<ReservasiService['findOne']>>;

const penggunaId = 'ec8a387e-f186-4324-8c6a-faec174ce55c';

const penggunaLainId = '00000000-0000-4000-8000-000000000002';

const tiketId = '1a33984d-d5f1-4fdb-b888-545a2c5be9c8';

const layananId = '1bfa9aa4-6c27-4e67-b938-b0fb53f485cf';

const tiketUji: DataReservasi = {
  id: tiketId,
  penggunaId,
  layananId,

  tanggalAntrean: new Date('2026-10-12T00:00:00.000Z'),

  nomorUrut: 1,
  kodeTiket: 'TK604CF19B8EBD8AFB1E1FC88D',
  status: StatusTiket.DIPESAN,

  dibuatPada: new Date('2026-10-09T23:58:48.838Z'),

  layanan: {
    id: layananId,
    kode: 'ADM',
    nama: 'Layanan Administrasi Umum',
    prefixAntrean: 'A',
  },
};

// ==========================================
// MOCK RESERVASI SERVICE
// ==========================================

const buatReservasiMock = () => ({
  findAll: jest.fn(),
  findOne: jest.fn(),
});

// ==========================================
// UNIT TEST TIKET SERVICE
// ==========================================

describe('TiketService', () => {
  let service: TiketService;

  let reservasiMock: ReturnType<typeof buatReservasiMock>;

  beforeEach(async () => {
    reservasiMock = buatReservasiMock();

    reservasiMock.findAll.mockResolvedValue([tiketUji]);

    reservasiMock.findOne.mockResolvedValue(tiketUji);

    const moduleRef = await Test.createTestingModule({
      providers: [
        TiketService,
        {
          provide: ReservasiService,
          useValue: reservasiMock,
        },
      ],
    }).compile();

    service = moduleRef.get<TiketService>(TiketService);
  });

  // ========================================
  // A. DAFTAR TIKET - 8 TEST
  // ========================================

  describe('Read All Tiket', () => {
    it('berhasil menampilkan tiket dengan nomor A-001', async () => {
      const hasil = await service.findAll(penggunaId);

      expect(hasil).toHaveLength(1);

      expect(hasil[0]).toMatchObject({
        id: tiketId,
        penggunaId,
        nomorUrut: 1,
        nomorAntrean: 'A-001',
        tanggalPelayanan: '2026-10-12',
        status: StatusTiket.DIPESAN,
      });
    });

    it('mengembalikan daftar kosong jika belum ada tiket', async () => {
      reservasiMock.findAll.mockResolvedValue([]);

      const hasil = await service.findAll(penggunaId);

      expect(hasil).toEqual([]);
    });

    it('memformat nomor urut 1 dan 12 dengan tiga digit', async () => {
      reservasiMock.findAll.mockResolvedValue([
        tiketUji,
        {
          ...tiketUji,
          id: '00000000-0000-4000-8000-000000000012',
          nomorUrut: 12,
        },
      ]);

      const hasil = await service.findAll(penggunaId);

      expect(hasil.map((tiket) => tiket.nomorAntrean)).toEqual([
        'A-001',
        'A-012',
      ]);
    });

    it('mempertahankan nomor antrean lebih dari 999', async () => {
      reservasiMock.findAll.mockResolvedValue([
        {
          ...tiketUji,
          nomorUrut: 1000,
        },
      ]);

      const hasil = await service.findAll(penggunaId);

      expect(hasil[0].nomorAntrean).toBe('A-1000');
    });

    it('membersihkan spasi pada prefix antrean', async () => {
      reservasiMock.findAll.mockResolvedValue([
        {
          ...tiketUji,
          nomorUrut: 7,
          layanan: {
            ...tiketUji.layanan,
            prefixAntrean: ' B ',
          },
        },
      ]);

      const hasil = await service.findAll(penggunaId);

      expect(hasil[0].nomorAntrean).toBe('B-007');
    });

    it('menghasilkan tanggal YYYY-MM-DD dari PostgreSQL DATE', async () => {
      reservasiMock.findAll.mockResolvedValue([
        {
          ...tiketUji,
          tanggalAntrean: new Date('2026-12-31T00:00:00.000Z'),
        },
      ]);

      const hasil = await service.findAll(penggunaId);

      expect(hasil[0].tanggalPelayanan).toBe('2026-12-31');
    });

    it('mempertahankan metadata tiket tanpa mengubah data asal', async () => {
      const hasil = await service.findAll(penggunaId);

      expect(hasil[0].kodeTiket).toBe(tiketUji.kodeTiket);

      expect(hasil[0].status).toBe(StatusTiket.DIPESAN);

      expect(hasil[0].layanan).toEqual(tiketUji.layanan);

      // Field baru hanya ada pada hasil format.
      expect(tiketUji).not.toHaveProperty('nomorAntrean');

      expect(tiketUji).not.toHaveProperty('tanggalPelayanan');

      // Proyeksi reservasi saat ini tidak
      // menyertakan hash token QR internal.
      expect(hasil[0]).not.toHaveProperty('tokenQrHash');
    });

    it('mempertahankan urutan tiket dari ReservasiService', async () => {
      reservasiMock.findAll.mockResolvedValue([
        {
          ...tiketUji,
          nomorUrut: 3,
        },
        {
          ...tiketUji,
          nomorUrut: 2,
        },
        {
          ...tiketUji,
          nomorUrut: 1,
        },
      ]);

      const hasil = await service.findAll(penggunaId);

      expect(hasil.map((tiket) => tiket.nomorAntrean)).toEqual([
        'A-003',
        'A-002',
        'A-001',
      ]);

      expect(reservasiMock.findAll).toHaveBeenCalledWith(penggunaId);
    });
  });

  // ========================================
  // B. DETAIL TIKET - 6 TEST
  // ========================================

  describe('Read One Tiket', () => {
    it('berhasil mengambil tiket dengan informasi lengkap', async () => {
      const hasil = await service.findOne(tiketId, penggunaId);

      expect(hasil).toMatchObject({
        id: tiketId,
        penggunaId,
        layananId,
        nomorUrut: 1,
        nomorAntrean: 'A-001',
        tanggalPelayanan: '2026-10-12',
        kodeTiket: tiketUji.kodeTiket,
        status: StatusTiket.DIPESAN,
      });

      expect(hasil.layanan.nama).toBe('Layanan Administrasi Umum');
    });

    it('meneruskan ID tiket dan identitas pengguna kepada ReservasiService', async () => {
      await service.findOne(tiketId, penggunaId);

      expect(reservasiMock.findOne).toHaveBeenCalledTimes(1);

      expect(reservasiMock.findOne).toHaveBeenCalledWith(tiketId, penggunaId);
    });

    it('meneruskan NotFoundException ketika tiket tidak ditemukan', async () => {
      reservasiMock.findOne.mockRejectedValue(
        new NotFoundException('Reservasi tidak ditemukan'),
      );

      await expect(service.findOne(tiketId, penggunaId)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('tetap menggunakan identitas pengguna untuk membatasi kepemilikan', async () => {
      reservasiMock.findOne.mockRejectedValue(
        new NotFoundException('Reservasi tidak ditemukan'),
      );

      await expect(service.findOne(tiketId, penggunaLainId)).rejects.toThrow(
        NotFoundException,
      );

      expect(reservasiMock.findOne).toHaveBeenCalledWith(
        tiketId,
        penggunaLainId,
      );
    });

    it('meneruskan kesalahan dari ReservasiService', async () => {
      reservasiMock.findOne.mockRejectedValue(new Error('Gangguan database'));

      await expect(service.findOne(tiketId, penggunaId)).rejects.toThrow(
        'Gangguan database',
      );
    });

    it('memformat nomor besar dan tanggal secara konsisten', async () => {
      reservasiMock.findOne.mockResolvedValue({
        ...tiketUji,
        nomorUrut: 1250,
        tanggalAntrean: new Date('2026-11-20T00:00:00.000Z'),
        layanan: {
          ...tiketUji.layanan,
          prefixAntrean: 'V',
        },
      });

      const hasil = await service.findOne(tiketId, penggunaId);

      expect(hasil.nomorAntrean).toBe('V-1250');

      expect(hasil.tanggalPelayanan).toBe('2026-11-20');

      expect(hasil.nomorUrut).toBe(1250);
    });
  });
});
