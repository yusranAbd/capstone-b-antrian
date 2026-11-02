import { BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LaporanService } from './laporan.service';
import { period } from './period-query';

describe('Operational reports (mock only)', () => {
  it.each([
    ['2026-02-30', '2026-03-01'],
    ['2026-11-03', '2026-11-02'],
    ['2026-10-01', '2026-11-01'],
    ['not-a-date', '2026-11-02'],
  ])('rejects invalid or oversized period %s / %s', (mulai, selesai) => {
    expect(() => period({ mulai, selesai })).toThrow(BadRequestException);
  });
  it('accepts a valid leap day and an inclusive 31-day period', () => {
    expect(
      period({
        mulai: '2028-02-29',
        selesai: '2028-03-30',
      }).mulai.toISOString(),
    ).toBe('2028-02-29T00:00:00.000Z');
  });
  it('keeps distinct patient totals from the overall aggregation, not a sum of per-day counts', async () => {
    const query = jest.fn().mockResolvedValue([
      {
        agregat: 1,
        totalTiket: 4,
        pasienUnik: 1,
        sampelTunggu: 0,
        rataTungguDetik: null,
      },
      { agregat: 0, tanggal: '2026-11-01', totalTiket: 2, pasienUnik: 1 },
      { agregat: 0, tanggal: '2026-11-02', totalTiket: 2, pasienUnik: 1 },
    ]);
    const service = new LaporanService({
      $queryRaw: query,
    } as unknown as PrismaService);
    const result = await service.read({
      mulai: '2026-11-01',
      selesai: '2026-11-02',
    });
    expect(result.ringkasan.pasienUnik).toBe(1);
    expect(result.ringkasan.rataTungguDetik).toBeNull();
    expect(result.baris).toHaveLength(2);
  });
  it('does not return a silently truncated report', async () => {
    const service = new LaporanService({
      $queryRaw: jest
        .fn()
        .mockResolvedValue(new Array(5002).fill({ agregat: 0 })),
    } as unknown as PrismaService);
    await expect(
      service.read({ mulai: '2026-11-02', selesai: '2026-11-02' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
