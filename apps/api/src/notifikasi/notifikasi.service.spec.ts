import { NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotifikasiService } from './notifikasi.service';

describe('Patient notification inbox (mock only)', () => {
  const notification = {
    count: jest.fn(),
    findMany: jest.fn(),
    updateMany: jest.fn(),
    findFirst: jest.fn(),
  };
  const prisma = {
    notifikasi: notification,
    $transaction: jest.fn((run: (tx: unknown) => unknown) =>
      run({ notifikasi: notification }),
    ),
  };
  const service = new NotifikasiService(prisma as unknown as PrismaService);
  beforeEach(() => jest.resetAllMocks());
  it('scopes both read mutation and response to the authenticated owner', async () => {
    notification.updateMany.mockResolvedValue({ count: 0 });
    notification.findFirst.mockResolvedValue(null);
    await expect(
      service.read('owner-a', 'another-owner-notification'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(notification.updateMany.mock.calls[0][0].where).toEqual({
      id: 'another-owner-notification',
      penggunaId: 'owner-a',
      dibacaPada: null,
    });
    expect(notification.findFirst.mock.calls[0][0].where.penggunaId).toBe(
      'owner-a',
    );
  });
  it('an already-read notification retains its original read timestamp', async () => {
    const row = {
      id: 'notification',
      dibacaPada: new Date('2026-11-01T00:00:00Z'),
    };
    notification.updateMany.mockResolvedValue({ count: 0 });
    notification.findFirst.mockResolvedValue(row);
    expect(await service.read('owner-a', row.id)).toBe(row);
  });
  it('pages an owned inbox and counts unread entries independently', async () => {
    prisma.$transaction.mockImplementation((run: (tx: unknown) => unknown) =>
      run({ notifikasi: notification }),
    );
    notification.count.mockResolvedValueOnce(41).mockResolvedValueOnce(3);
    notification.findMany.mockResolvedValue([]);
    expect(await service.list('owner-a', 3)).toMatchObject({
      total: 41,
      belumDibaca: 3,
      halaman: 3,
      jumlahHalaman: 3,
    });
    expect(notification.findMany.mock.calls[0][0]).toMatchObject({
      where: { penggunaId: 'owner-a' },
      skip: 40,
      take: 20,
    });
  });
});
