import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { configureApp } from '../src/configure-app';
import { PeranPengguna } from '../src/generated/prisma/client';
import { PrismaService } from '../src/prisma/prisma.service';

interface RegisterResponse {
  id: string;
}

interface LoginResponse {
  accessToken: string;
  user: {
    id: string;
    peran: PeranPengguna;
  };
}

interface LoketResponse {
  id: string;
  layananId: string;
  kode: string;
  nama: string;
  lokasi: string | null;
  aktif: boolean;
  layanan: {
    id: string;
    kode: string;
    nama: string;
    aktif: boolean;
  };
}

describe('Manajemen Loket API (e2e)', () => {
  let app: INestApplication | undefined;
  let prisma: PrismaService | undefined;

  const unik = randomUUID().replace(/-/g, '').slice(0, 10).toUpperCase();

  const emailUser = `loket-user-${unik}@test.local`;
  const emailAdmin = `loket-admin-${unik}@test.local`;
  const kataSandi = 'RahasiaE2E123!';

  const kodeLayananSatu = `A${unik}`;
  const kodeLayananDua = `B${unik}`;
  const kodeLoket = 'LKT-E2E';

  const penggunaIds: string[] = [];

  let layananSatuId = '';
  let layananDuaId = '';
  let loketSatuId = '';
  let loketDuaId = '';

  let tokenUser = '';
  let tokenAdmin = '';

  function httpServer() {
    if (!app) {
      throw new Error('Aplikasi testing belum siap');
    }

    return app.getHttpServer();
  }

  function database(): PrismaService {
    if (!prisma) {
      throw new Error('Database testing belum siap');
    }

    return prisma;
  }

  async function buatAkun(
    nama: string,
    email: string,
    peran: PeranPengguna,
  ): Promise<string> {
    const registrasi = await request(httpServer())
      .post('/api/v1/auth/register')
      .send({ nama, email, kataSandi })
      .expect(201);

    const pengguna = registrasi.body as RegisterResponse;
    penggunaIds.push(pengguna.id);

    if (peran === PeranPengguna.ADMIN) {
      await database().pengguna.update({
        where: { id: pengguna.id },
        data: { peran: PeranPengguna.ADMIN },
      });
    }

    const login = await request(httpServer())
      .post('/api/v1/auth/login')
      .send({
        email,
        kataSandi,
        namaPerangkat: 'Jest E2E Loket',
      })
      .expect(200);

    const hasil = login.body as LoginResponse;

    expect(hasil.user.peran).toBe(peran);

    return hasil.accessToken;
  }

  // ==========================================
  // SETUP DATABASE TESTING
  // ==========================================

  beforeAll(async () => {
    const databaseUrl = process.env.DATABASE_URL;

    if (!databaseUrl) {
      throw new Error('DATABASE_URL testing wajib ditentukan');
    }

    const url = new URL(databaseUrl);

    if (
      url.pathname !== '/capstone_antrean_test' ||
      !['127.0.0.1', 'localhost'].includes(url.hostname) ||
      url.port !== '5433'
    ) {
      throw new Error(
        'Pengujian hanya diizinkan pada ' +
          'capstone_antrean_test lokal port 5433',
      );
    }

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    configureApp(app);

    await app.init();

    prisma = app.get(PrismaService);

    // Buat akun pengujian.
    tokenUser = await buatAkun(
      'Pengguna Uji Loket',
      emailUser,
      PeranPengguna.USER,
    );

    tokenAdmin = await buatAkun(
      'Admin Uji Loket',
      emailAdmin,
      PeranPengguna.ADMIN,
    );

    // Buat dua layanan agar pengujian tidak
    // bergantung pada data seed development.
    const layananSatu = await database().layanan.create({
      data: {
        kode: kodeLayananSatu,
        nama: 'Layanan E2E Satu',
        deskripsi: 'Khusus pengujian loket',
        prefixAntrean: 'A',
        durasiDasarMenit: 15,
        aktif: true,
      },
    });

    layananSatuId = layananSatu.id;

    const layananDua = await database().layanan.create({
      data: {
        kode: kodeLayananDua,
        nama: 'Layanan E2E Dua',
        deskripsi: 'Khusus pengujian loket',
        prefixAntrean: 'B',
        durasiDasarMenit: 10,
        aktif: true,
      },
    });

    layananDuaId = layananDua.id;
  });

  // ==========================================
  // CLEANUP DATA PENGUJIAN
  // ==========================================

  afterAll(async () => {
    try {
      if (prisma) {
        const layananIds = [layananSatuId, layananDuaId].filter(Boolean);

        if (layananIds.length > 0) {
          await prisma.loket.deleteMany({
            where: {
              layananId: { in: layananIds },
            },
          });

          await prisma.layanan.deleteMany({
            where: {
              id: { in: layananIds },
            },
          });
        }

        if (penggunaIds.length > 0) {
          await prisma.sesiPengguna.deleteMany({
            where: {
              penggunaId: { in: penggunaIds },
            },
          });

          await prisma.pengguna.deleteMany({
            where: {
              id: { in: penggunaIds },
            },
          });
        }
      }
    } finally {
      if (app) {
        await app.close();
      }
    }
  });

  // ==========================================
  // 1. AUTHENTICATION DAN RBAC
  // ==========================================

  it('menolak akses tanpa JWT dan operasi ADMIN oleh USER', async () => {
    const body = {
      layananId: layananSatuId,
      kode: kodeLoket,
      nama: 'Loket Pengujian',
      lokasi: 'Ruang E2E',
    };

    await request(httpServer()).post('/api/v1/loket').send(body).expect(401);

    await request(httpServer()).get('/api/v1/loket').expect(401);

    await request(httpServer())
      .post('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenUser}`)
      .send(body)
      .expect(403);
  });

  // ==========================================
  // 2. VALIDASI INPUT DAN LAYANAN
  // ==========================================

  it('menolak input dan relasi layanan yang tidak valid', async () => {
    await request(httpServer())
      .post('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        layananId: 'bukan-uuid',
        kode: 'kode tidak valid',
        nama: 'A',
        lokasi: 'Ruang E2E',
      })
      .expect(400);

    const idTidakAda = '00000000-0000-4000-8000-000000000000';

    await request(httpServer())
      .post('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        layananId: idTidakAda,
        kode: kodeLoket,
        nama: 'Loket Pengujian',
      })
      .expect(404);

    await database().layanan.update({
      where: { id: layananDuaId },
      data: { aktif: false },
    });

    try {
      await request(httpServer())
        .post('/api/v1/loket')
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({
          layananId: layananDuaId,
          kode: kodeLoket,
          nama: 'Loket Pengujian',
        })
        .expect(400);
    } finally {
      await database().layanan.update({
        where: { id: layananDuaId },
        data: { aktif: true },
      });
    }
  });

  // ==========================================
  // 3. CREATE DAN UNIQUE CONSTRAINT
  // ==========================================

  it('membuat loket dan memvalidasi keunikan kode per layanan', async () => {
    const body = {
      layananId: layananSatuId,
      kode: kodeLoket,
      nama: 'Loket Pengujian Satu',
      lokasi: 'Ruang Pelayanan 1',
    };

    const response = await request(httpServer())
      .post('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send(body)
      .expect(201);

    const loket = response.body as LoketResponse;

    loketSatuId = loket.id;

    expect(loket.layananId).toBe(layananSatuId);
    expect(loket.aktif).toBe(true);
    expect(loket.layanan.id).toBe(layananSatuId);

    // Kode sama pada layanan sama: 409.
    await request(httpServer())
      .post('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send(body)
      .expect(409);

    // Kode sama pada layanan berbeda: boleh.
    const responseDua = await request(httpServer())
      .post('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        ...body,
        layananId: layananDuaId,
        nama: 'Loket Pengujian Dua',
      })
      .expect(201);

    const loketDua = responseDua.body as LoketResponse;

    loketDuaId = loketDua.id;

    expect(loketDua.layananId).toBe(layananDuaId);
    expect(loketDua.kode).toBe(kodeLoket);
  });

  // ==========================================
  // 4. READ ALL DAN READ ONE
  // ==========================================

  it('ADMIN dan USER dapat melihat loket aktif', async () => {
    const adminResponse = await request(httpServer())
      .get('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(200);

    const daftarAdmin = adminResponse.body as LoketResponse[];

    expect(daftarAdmin.some((item) => item.id === loketSatuId)).toBe(true);

    const userResponse = await request(httpServer())
      .get('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);

    const daftarUser = userResponse.body as LoketResponse[];

    expect(daftarUser.some((item) => item.id === loketSatuId)).toBe(true);

    const detail = await request(httpServer())
      .get(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);

    const loket = detail.body as LoketResponse;

    expect(loket.kode).toBe(kodeLoket);
    expect(loket.layanan.id).toBe(layananSatuId);
  });

  // ==========================================
  // 5. UPDATE DAN KONFLIK RELASI
  // ==========================================

  it('ADMIN dapat update dan perpindahan duplikat ditolak', async () => {
    await request(httpServer())
      .patch(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .send({ nama: 'Perubahan Tidak Sah' })
      .expect(403);

    const response = await request(httpServer())
      .patch(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        nama: 'Loket Administrasi Utama',
        lokasi: 'Ruang Pelayanan Lantai 1',
      })
      .expect(200);

    const loket = response.body as LoketResponse;

    expect(loket.nama).toBe('Loket Administrasi Utama');

    expect(loket.lokasi).toBe('Ruang Pelayanan Lantai 1');

    // Layanan kedua sudah memiliki kode sama.
    await request(httpServer())
      .patch(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ layananId: layananDuaId })
      .expect(409);
  });

  // ==========================================
  // 6. SOFT DELETE
  // ==========================================

  it('soft delete menyembunyikan loket dari USER', async () => {
    await request(httpServer())
      .delete(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(403);

    const response = await request(httpServer())
      .delete(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(200);

    const loket = response.body as LoketResponse;

    expect(loket.aktif).toBe(false);

    await request(httpServer())
      .get(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(404);

    const daftarResponse = await request(httpServer())
      .get('/api/v1/loket')
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);

    const daftar = daftarResponse.body as LoketResponse[];

    expect(daftar.some((item) => item.id === loketSatuId)).toBe(false);

    // ADMIN masih dapat melihat loket nonaktif.
    await request(httpServer())
      .get(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(200);
  });

  // ==========================================
  // 7. REAKTIVASI
  // ==========================================

  it('ADMIN dapat mengaktifkan kembali loket', async () => {
    const response = await request(httpServer())
      .patch(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ aktif: true })
      .expect(200);

    const loket = response.body as LoketResponse;

    expect(loket.aktif).toBe(true);

    await request(httpServer())
      .get(`/api/v1/loket/${loketSatuId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);
  });

  // ==========================================
  // 8. LAYANAN INDUK NONAKTIF
  // ==========================================

  it('menyembunyikan loket ketika layanan induk nonaktif', async () => {
    await database().layanan.update({
      where: { id: layananSatuId },
      data: { aktif: false },
    });

    try {
      await request(httpServer())
        .get(`/api/v1/loket/${loketSatuId}`)
        .set('Authorization', `Bearer ${tokenUser}`)
        .expect(404);

      const response = await request(httpServer())
        .get('/api/v1/loket')
        .set('Authorization', `Bearer ${tokenUser}`)
        .expect(200);

      const daftar = response.body as LoketResponse[];

      expect(daftar.some((item) => item.id === loketSatuId)).toBe(false);

      // ADMIN tetap dapat melihatnya.
      await request(httpServer())
        .get(`/api/v1/loket/${loketSatuId}`)
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .expect(200);
    } finally {
      await database().layanan.update({
        where: { id: layananSatuId },
        data: { aktif: true },
      });
    }
  });

  // ==========================================
  // 9. NOT FOUND DAN INVALID UUID
  // ==========================================

  it('mengembalikan 404 dan 400 untuk ID tidak valid', async () => {
    const idTidakAda = '00000000-0000-4000-8000-000000000000';

    await request(httpServer())
      .get(`/api/v1/loket/${idTidakAda}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(404);

    await request(httpServer())
      .get('/api/v1/loket/bukan-uuid')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(400);

    expect(loketDuaId).toBeTruthy();
  });
});
