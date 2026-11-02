import { Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { UsersService } from '../../users/users.service';
import { PasswordService } from '../password.service';
import { AuthService } from '../auth.service';
import { AuthAuditService, authAuditContext } from './auth-audit.service';

const marker = 'SYNTHETIC_SECRET_DO_NOT_LOG';
const account = '11111111-1111-4111-8111-111111111111';
const session = '22222222-2222-4222-8222-222222222222';
describe('Safe session audit (mock only)', () => {
  it('records only allowlisted fields, with random server request IDs and unverified client claims', async () => {
    const create = jest.fn().mockResolvedValue({}),
      prune = jest.fn().mockResolvedValue({ count: 0 });
    const service = new AuthAuditService({
      $transaction: async (run: (tx: unknown) => unknown) =>
        run({ auditSesi: { create, deleteMany: prune } }),
    } as unknown as PrismaService);
    const context = {
      ...authAuditContext('WEB'),
      akunRef: account,
      sesiRef: session,
      refreshToken: marker,
      password: marker,
      headers: { authorization: marker },
    };
    await service.record('REFRESH', context, 'BERHASIL', 'OK');
    const data = create.mock.calls[0][0].data;
    expect(data).toMatchObject({
      akunRef: account,
      sesiRef: session,
      klien: 'WEB',
      sumber: 'UNKNOWN',
    });
    expect(JSON.stringify(data)).not.toContain(marker);
    expect(data).not.toHaveProperty('headers');
    expect(authAuditContext(marker).klien).toBe('UNKNOWN');
    expect(authAuditContext().requestId).not.toBe(authAuditContext().requestId);
    await service.record(
      'LOGIN',
      { ...authAuditContext(), akunRef: account },
      'DITOLAK',
      'CREDENTIALS_REJECTED',
    );
    expect(create.mock.calls[1][0].data).toMatchObject({
      akunRef: account,
      aktorRef: null,
    });
  });
  it('preserves availability and never logs a sink exception containing secret markers', async () => {
    const log = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => undefined);
    try {
      const service = new AuthAuditService({
        $transaction: jest.fn().mockRejectedValue(new Error(marker)),
      } as unknown as PrismaService);
      await expect(
        service.record(
          'LOGIN',
          authAuditContext(),
          'DITOLAK',
          'CREDENTIALS_REJECTED',
        ),
      ).resolves.toBeUndefined();
      expect(JSON.stringify(log.mock.calls)).not.toContain(marker);
      expect(log).toHaveBeenCalled();
    } finally {
      log.mockRestore();
    }
  });
  it('a rejecting audit adapter cannot turn successful committed login into failure', async () => {
    const audit = { record: jest.fn().mockRejectedValue(new Error(marker)) };
    const tx = {
      $executeRaw: jest.fn(),
      $queryRaw: jest.fn().mockResolvedValue([{ id: 'user' }]),
      sesiPengguna: {
        create: jest.fn().mockResolvedValue({ auditRef: session }),
      },
    };
    const service = new AuthService(
      {
        findByEmail: jest.fn().mockResolvedValue({
          id: 'user',
          email: 'synthetic@example.test',
          nama: 'Synthetic',
          peran: 'USER',
          aktif: true,
          auditRef: account,
          kataSandiHash: 'hash',
        }),
      } as unknown as UsersService,
      {
        verify: jest.fn().mockResolvedValue(true),
      } as unknown as PasswordService,
      {
        signAsync: jest.fn().mockResolvedValue(marker),
      } as unknown as JwtService,
      {
        getOrThrow: jest.fn((key: string) =>
          key.includes('EXPIRES') ? '7d' : 'synthetic-key',
        ),
      } as unknown as ConfigService,
      {
        $transaction: (run: (client: unknown) => unknown) => run(tx),
      } as unknown as PrismaService,
      audit as unknown as AuthAuditService,
    );
    const result = await service.login({
      email: 'synthetic@example.test',
      kataSandi: marker,
    });
    expect(result.accessToken).toBe(marker);
    expect(audit.record).toHaveBeenCalledTimes(1);
    expect(JSON.stringify(audit.record.mock.calls)).not.toContain(marker);
  });
  it('keeps the original unauthorized result when audit persistence also fails', async () => {
    const audit = { record: jest.fn().mockRejectedValue(new Error(marker)) };
    const service = new AuthService(
      {
        findByEmail: jest.fn().mockResolvedValue(null),
      } as unknown as UsersService,
      {} as PasswordService,
      {} as JwtService,
      {} as ConfigService,
      {} as PrismaService,
      audit as unknown as AuthAuditService,
    );
    await expect(
      service.login({ email: 'synthetic@example.test', kataSandi: marker }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(audit.record.mock.calls[0][2]).toBe('DITOLAK');
    expect(JSON.stringify(audit.record.mock.calls)).not.toContain(marker);
  });
});
