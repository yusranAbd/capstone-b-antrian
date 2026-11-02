import { PrismaService } from '../prisma/prisma.service';
import { kategoriDariKode } from './kategori-layanan';
import { LayananReadinessService } from './layanan-readiness.service';

describe('Service configuration readiness (no database)', () => {
  const findMany = jest.fn();
  const service = new LayananReadinessService({
    layanan: { findMany },
  } as unknown as PrismaService);
  const daily = () => ({
    id: 'registration',
    aktif: true,
    modeReservasi: 'ANTREAN_HARIAN',
    jadwalLayanan: [
      {
        kapasitasHarian: 100,
        jamBuka: new Date('1970-01-01T08:00:00Z'),
        jamTutup: new Date('1970-01-01T16:00:00Z'),
      },
    ],
    loket: [
      {
        id: 'room',
        nama: 'Pendaftaran',
        penugasanPetugas: [{ id: 'assignment' }],
      },
    ],
    dokterLayanan: [],
  });
  it('does not require a doctor or appointment slots for a daily registration service', async () => {
    findMany.mockResolvedValue([daily()]);
    expect(await service.snapshot()).toEqual([
      expect.objectContaining({ lengkap: true, kekurangan: [] }),
    ]);
  });
  it('identifies missing appointment configuration and unstaffed rooms', async () => {
    const row = daily();
    row.modeReservasi = 'HIBRIDA';
    row.loket[0].penugasanPetugas = [];
    findMany.mockResolvedValue([row]);
    const [report] = await service.snapshot();
    expect(report.lengkap).toBe(false);
    expect(report.kekurangan).toHaveLength(3);
    expect(report.kekurangan.join(' ')).toMatch(/petugas.*dokter.*sesi/);
  });
  it('preserves registration aliases for clients without the category field', () => {
    for (const code of ['DAFTAR', 'PENDAFTARAN', 'REGISTRASI', 'ADMINISTRASI'])
      expect(kategoriDariKode(code)).toBe('PENDAFTARAN');
    expect(kategoriDariKode('APOTIK')).toBe('APOTEK');
    expect(kategoriDariKode('CUSTOM')).toBe('POLIKLINIK');
  });
});
