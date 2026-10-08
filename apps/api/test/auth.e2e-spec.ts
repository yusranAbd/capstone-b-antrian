import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { configureApp } from '../src/configure-app';
import { PeranPengguna } from '../src/generated/prisma/client';
import { PrismaService } from '../src/prisma/prisma.service';

import { Controller, Get, UseGuards } from '@nestjs/common';
import { Roles } from '../src/auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard';
import { RolesGuard } from '../src/auth/guards/roles.guard';

interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    nama: string;
    email: string;
    peran: PeranPengguna;
  };
}

interface RegisterResponse {
  id: string;
  nama: string;
  email: string;
  peran: PeranPengguna;
  kataSandiHash?: string;
}

@Controller('__e2e/rbac')
class RbacTestController {
  @Get('petugas')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(PeranPengguna.PETUGAS, PeranPengguna.ADMIN)
  cekPetugas() {
    return {
      message: 'Akses petugas diizinkan',
    };
  }

  @Get('admin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(PeranPengguna.ADMIN)
  cekAdmin() {
    return {
      message: 'Akses admin diizinkan',
    };
  }
}

describe('Authentication API (e2e)', () => {
  let app: INestApplication | undefined;
  let prisma: PrismaService | undefined;

  const email = `auth-e2e-${randomUUID()}@test.local`;
  const kataSandi = 'RahasiaE2E123!';

  let penggunaId = '';
  let accessToken = '';
  let refreshToken = '';

  function httpServer() {
    if (!app) {
      throw new Error('Aplikasi testing belum tersedia');
    }

    return app.getHttpServer();
  }

  function database(): PrismaService {
    if (!prisma) {
      throw new Error('Prisma testing belum tersedia');
    }

    return prisma;
  }

  beforeAll(async () => {
    // Pengamanan agar test tidak mengubah
    // database development atau production.
    const databaseUrl = process.env.DATABASE_URL;

    if (!databaseUrl) {
      throw new Error('DATABASE_URL testing wajib ditentukan');
    }

    const databaseName = new URL(databaseUrl).pathname.slice(1);

    if (databaseName !== 'capstone_antrean_test') {
      throw new Error(
        'E2E autentikasi hanya boleh berjalan ' +
          'pada database capstone_antrean_test',
      );
    }

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
      controllers: [RbacTestController],
    }).compile();

    app = moduleRef.createNestApplication();

    configureApp(app);

    await app.init();

    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    try {
      if (prisma && penggunaId) {
        await prisma.sesiPengguna.deleteMany({
          where: {
            penggunaId,
          },
        });

        await prisma.pengguna.delete({
          where: {
            id: penggunaId,
          },
        });
      }
    } finally {
      if (app) {
        await app.close();
      }
    }
  });

  // ========================================
  // 1. REGISTRASI
  // ========================================

  it('registrasi berhasil dan email duplikat ditolak', async () => {
    const data = {
      nama: 'Pengguna E2E',
      email,
      kataSandi,
    };

    const response = await request(httpServer())
      .post('/api/v1/auth/register')
      .send(data)
      .expect(201);

    const pengguna = response.body as RegisterResponse;

    penggunaId = pengguna.id;

    expect(pengguna.email).toBe(email);
    expect(pengguna.peran).toBe(PeranPengguna.USER);
    expect(pengguna.kataSandiHash).toBeUndefined();

    await request(httpServer())
      .post('/api/v1/auth/register')
      .send(data)
      .expect(409);
  });

  // ========================================
  // 2. LOGIN DAN JWT
  // ========================================

  it('login berhasil dan endpoint me dilindungi JWT', async () => {
    await request(httpServer())
      .post('/api/v1/auth/login')
      .send({
        email,
        kataSandi: 'PasswordSalah123!',
      })
      .expect(401);

    const response = await request(httpServer())
      .post('/api/v1/auth/login')
      .send({
        email,
        kataSandi,
        namaPerangkat: 'Jest E2E',
      })
      .expect(200);

    const hasil = response.body as AuthResponse;

    accessToken = hasil.accessToken;
    refreshToken = hasil.refreshToken;

    expect(accessToken).toBeTruthy();
    expect(refreshToken).toBeTruthy();
    expect(hasil.user.peran).toBe(PeranPengguna.USER);

    await request(httpServer()).get('/api/v1/auth/me').expect(401);

    const profil = await request(httpServer())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(profil.body).toEqual(
      expect.objectContaining({
        id: penggunaId,
        email,
        peran: PeranPengguna.USER,
      }),
    );
  });

  // ========================================
  // 3. ROLE-BASED ACCESS CONTROL
  // ========================================

  it('membatasi akses USER, PETUGAS, dan ADMIN', async () => {
    // USER tidak mempunyai akses operasional.
    await request(httpServer())
      .get('/api/v1/__e2e/rbac/petugas')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(403);

    await request(httpServer())
      .get('/api/v1/__e2e/rbac/admin')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(403);

    try {
      // Ubah role hanya pada database testing.
      await database().pengguna.update({
        where: { id: penggunaId },
        data: { peran: PeranPengguna.PETUGAS },
      });

      // JwtStrategy membaca role terbaru dari DB.
      await request(httpServer())
        .get('/api/v1/__e2e/rbac/petugas')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      await request(httpServer())
        .get('/api/v1/__e2e/rbac/admin')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(403);

      // Pengujian ADMIN.
      await database().pengguna.update({
        where: { id: penggunaId },
        data: { peran: PeranPengguna.ADMIN },
      });

      await request(httpServer())
        .get('/api/v1/__e2e/rbac/admin')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      await request(httpServer())
        .get('/api/v1/__e2e/rbac/petugas')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);
    } finally {
      // Selalu kembalikan role ke USER.
      await database().pengguna.update({
        where: { id: penggunaId },
        data: { peran: PeranPengguna.USER },
      });
    }
  });

  // ========================================
  // 4. REFRESH TOKEN ROTATION
  // ========================================

  it('hanya satu concurrent refresh yang berhasil', async () => {
    const tokenLama = refreshToken;

    const [responseA, responseB] = await Promise.all([
      request(httpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: tokenLama }),

      request(httpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: tokenLama }),
    ]);

    const statuses = [responseA.status, responseB.status].sort((a, b) => a - b);

    expect(statuses).toEqual([200, 401]);

    const berhasil = responseA.status === 200 ? responseA : responseB;

    const hasil = berhasil.body as AuthResponse;

    expect(hasil.refreshToken).toBeTruthy();
    expect(hasil.refreshToken).not.toBe(tokenLama);

    refreshToken = hasil.refreshToken;

    // Token lama tidak boleh dipakai kembali.
    await request(httpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: tokenLama })
      .expect(401);

    // Token baru harus masih bisa digunakan.
    const berikutnya = await request(httpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken })
      .expect(200);

    const hasilBerikutnya = berikutnya.body as AuthResponse;

    expect(hasilBerikutnya.refreshToken).not.toBe(refreshToken);

    refreshToken = hasilBerikutnya.refreshToken;
  });

  // ========================================
  // 5. LOGOUT DAN SESSION REVOCATION
  // ========================================

  it('logout mencabut sesi dan menolak refresh berikutnya', async () => {
    const response = await request(httpServer())
      .post('/api/v1/auth/logout')
      .send({ refreshToken })
      .expect(200);

    expect(response.body).toEqual({
      message: 'Logout berhasil',
    });

    await request(httpServer())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(401);

    const sesi = await database().sesiPengguna.findFirst({
      where: {
        penggunaId,
        dicabutPada: {
          not: null,
        },
      },
    });

    expect(sesi).not.toBeNull();
    expect(sesi?.dicabutPada).toBeInstanceOf(Date);

    await request(httpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken })
      .expect(401);
  });

  it('membatasi percobaan login berlebihan', async () => {
    const statusCodes: number[] = [];

    for (let i = 0; i < 6; i++) {
      const response = await request(httpServer())
        .post('/api/v1/auth/login')
        .send({
          email: 'akun-tidak-ada@test.local',
          kataSandi: 'PasswordSalah123!',
        });

      statusCodes.push(response.status);
    }

    // Setiap request harus ditolak karena
    // kredensial salah atau rate limit tercapai.
    expect(
      statusCodes.every((status) => status === 401 || status === 429),
    ).toBe(true);

    // Membuktikan throttling benar-benar aktif.
    expect(statusCodes).toContain(429);
  });
});
