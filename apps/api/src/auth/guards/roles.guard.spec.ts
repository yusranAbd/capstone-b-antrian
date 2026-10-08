import type { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PeranPengguna } from '../../generated/prisma/client';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { RolesGuard } from './roles.guard';

describe('RolesGuard', () => {
  let guard: RolesGuard;

  beforeEach(() => {
    guard = new RolesGuard(new Reflector());
  });

  function createContext(
    role: PeranPengguna | null,
    allowedRoles: PeranPengguna[],
  ): ExecutionContext {
    const handler = () => undefined;

    Reflect.defineMetadata(ROLES_KEY, allowedRoles, handler);

    return {
      getHandler: () => handler,
      getClass: () => class TestController {},
      switchToHttp: () => ({
        getRequest: () => ({
          user: role ? { peran: role } : undefined,
        }),
      }),
    } as unknown as ExecutionContext;
  }

  it('USER tidak boleh mengakses endpoint ADMIN', () => {
    const context = createContext(PeranPengguna.USER, [PeranPengguna.ADMIN]);

    expect(guard.canActivate(context)).toBe(false);
  });

  it('PETUGAS boleh mengakses endpoint PETUGAS', () => {
    const context = createContext(PeranPengguna.PETUGAS, [
      PeranPengguna.PETUGAS,
      PeranPengguna.ADMIN,
    ]);

    expect(guard.canActivate(context)).toBe(true);
  });

  it('PETUGAS tidak boleh mengakses endpoint ADMIN', () => {
    const context = createContext(PeranPengguna.PETUGAS, [PeranPengguna.ADMIN]);

    expect(guard.canActivate(context)).toBe(false);
  });

  it('ADMIN boleh mengakses endpoint ADMIN', () => {
    const context = createContext(PeranPengguna.ADMIN, [PeranPengguna.ADMIN]);

    expect(guard.canActivate(context)).toBe(true);
  });

  it('Pengguna tanpa autentikasi ditolak', () => {
    const context = createContext(null, [PeranPengguna.ADMIN]);

    expect(guard.canActivate(context)).toBe(false);
  });
});
