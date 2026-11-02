import { ConflictException, ForbiddenException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeBroadcastService } from '../realtime/realtime-broadcast.service';
import { BatalkanSesiBerakhirDto } from './dto/batalkan-sesi-berakhir.dto';
import { QueueResolutionService } from './queue-resolution.service';

describe('Staff resolution of an ended appointment session (no database)', () => {
  const dto: BatalkanSesiBerakhirDto = {
    loketId: '11111111-1111-4111-8111-111111111111',
    alasan: 'LAYANAN_TIDAK_DAPAT_DILANJUTKAN',
  };
  const session = () => ({
    id: 'session',
    tanggal: new Date('2026-11-02T00:00:00Z'),
    loketId: dto.loketId,
    selesaiPada: new Date('2026-11-02T07:00:00Z'),
    dokterLayanan: { layananId: 'service' },
  });
  const ticket = () => ({
    id: 'ticket',
    layananId: 'service',
    loketId: null,
    tanggalAntrean: new Date('2026-11-02T00:00:00Z'),
    status: 'MENUNGGU',
    versi: 3,
    nomorUrut: 2,
    urutanMasukAntrean: 5,
    layanan: { prefixAntrean: 'G' },
    janjiTemu: { slotPraktik: { jadwalPraktik: session() } },
  });
  const tx = {
    $queryRaw: jest.fn(),
    janjiTemu: { findUnique: jest.fn() },
    penugasanPetugas: { findFirst: jest.fn() },
    tiketAntrean: { findUnique: jest.fn(), updateMany: jest.fn() },
    peristiwaAntrean: { create: jest.fn() },
  };
  const transaction = jest.fn((run: (client: unknown) => unknown) => run(tx));
  const broadcast = jest.fn();
  const service = new QueueResolutionService(
    { $transaction: transaction } as unknown as PrismaService,
    { kirim: broadcast } as unknown as RealtimeBroadcastService,
  );
  let zone: string | undefined;
  beforeEach(() => {
    zone = process.env.SERVICE_TIME_ZONE;
    process.env.SERVICE_TIME_ZONE = 'Asia/Jakarta';
    jest.useFakeTimers().setSystemTime(new Date('2026-11-02T08:00:00Z'));
    jest.clearAllMocks();
    tx.$queryRaw.mockResolvedValue([]);
    tx.janjiTemu.findUnique.mockResolvedValue({
      slotPraktikId: 'slot',
      slotPraktik: { jadwalPraktikId: 'session' },
    });
    tx.penugasanPetugas.findFirst.mockResolvedValue({
      id: 'assignment',
      loket: { kode: 'G-1', layananId: 'service' },
    });
    tx.tiketAntrean.findUnique.mockResolvedValue(ticket());
    tx.tiketAntrean.updateMany.mockResolvedValue({ count: 1 });
    tx.peristiwaAntrean.create.mockResolvedValue({});
    broadcast.mockResolvedValue(undefined);
  });
  afterEach(() => {
    jest.useRealTimers();
    if (zone === undefined) delete process.env.SERVICE_TIME_ZONE;
    else process.env.SERVICE_TIME_ZONE = zone;
  });
  it('requires a real, active PETUGAS assignment for this room and date', async () => {
    tx.penugasanPetugas.findFirst.mockResolvedValue(null);
    await expect(
      service.batalkan('ticket', 'staff', dto),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(tx.penugasanPetugas.findFirst.mock.calls[0][0].where).toMatchObject({
      petugasId: 'staff',
      loketId: dto.loketId,
      aktif: true,
      petugas: { aktif: true, peran: 'PETUGAS' },
    });
    expect(tx.tiketAntrean.updateMany).not.toHaveBeenCalled();
  });
  it.each(['DIPANGGIL', 'DILAYANI', 'SELESAI', 'DIBATALKAN'])(
    'cannot cancel a ticket that is already %s',
    async (status) => {
      tx.tiketAntrean.findUnique.mockResolvedValue({ ...ticket(), status });
      await expect(
        service.batalkan('ticket', 'staff', dto),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(broadcast).not.toHaveBeenCalled();
    },
  );
  it('rejects an ongoing session, another room and a previous service day', async () => {
    const row = ticket();
    row.janjiTemu.slotPraktik.jadwalPraktik.selesaiPada = new Date(
      '2026-11-02T09:00:00Z',
    );
    tx.tiketAntrean.findUnique.mockResolvedValue(row);
    await expect(
      service.batalkan('ticket', 'staff', dto),
    ).rejects.toBeInstanceOf(ConflictException);
    row.janjiTemu.slotPraktik.jadwalPraktik = {
      ...session(),
      loketId: 'another-room',
    };
    await expect(
      service.batalkan('ticket', 'staff', dto),
    ).rejects.toBeInstanceOf(ForbiddenException);
    row.janjiTemu.slotPraktik.jadwalPraktik = session();
    row.tanggalAntrean = new Date('2026-11-01T00:00:00Z');
    await expect(
      service.batalkan('ticket', 'staff', dto),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.tiketAntrean.updateMany).not.toHaveBeenCalled();
  });
  it('uses optimistic status/version and writes reason + actor in the same transaction before notifying', async () => {
    const result = await service.batalkan('ticket', 'staff', dto);
    expect(result).toMatchObject({
      status: 'DIBATALKAN',
      versi: 4,
      nomorAntrean: 'G-002',
      urutanMasukAntrean: 5,
    });
    expect(tx.tiketAntrean.updateMany.mock.calls[0][0].where).toEqual({
      id: 'ticket',
      status: 'MENUNGGU',
      versi: 3,
    });
    expect(tx.peristiwaAntrean.create.mock.calls[0][0].data).toMatchObject({
      aktorId: 'staff',
      tipe: 'CANCEL_SESSION_ENDED',
      dataTambahan: { alasan: dto.alasan, penugasanId: 'assignment' },
    });
    expect(broadcast.mock.calls[0][0]).toMatchObject({
      aksi: 'CANCEL',
      status: 'DIBATALKAN',
    });
  });
  it('never audits or broadcasts when another command wins the status change', async () => {
    tx.tiketAntrean.updateMany.mockResolvedValue({ count: 0 });
    await expect(
      service.batalkan('ticket', 'staff', dto),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.peristiwaAntrean.create).not.toHaveBeenCalled();
    expect(broadcast).not.toHaveBeenCalled();
  });
  it('does not broadcast if audit persistence fails', async () => {
    tx.peristiwaAntrean.create.mockRejectedValueOnce(new Error('audit failed'));
    await expect(service.batalkan('ticket', 'staff', dto)).rejects.toThrow(
      'audit failed',
    );
    expect(broadcast).not.toHaveBeenCalled();
  });
  it('rejects an absent, arbitrary or null cancellation reason', async () => {
    for (const alasan of [undefined, 'OTHER', null]) {
      expect(
        (
          await validate(
            plainToInstance(BatalkanSesiBerakhirDto, {
              loketId: dto.loketId,
              alasan,
            }),
          )
        ).length,
      ).toBeGreaterThan(0);
    }
    expect(
      await validate(plainToInstance(BatalkanSesiBerakhirDto, dto)),
    ).toHaveLength(0);
  });
});
