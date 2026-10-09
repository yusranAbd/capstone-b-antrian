import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { configureApp } from '../src/configure-app';
import { HariLayanan, PeranPengguna } from '../src/generated/prisma/client';
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

interface JadwalResponse {
  id: string;
  layananId: string;
  hari: HariLayanan;
  jamBuka: string;
  jamTutup: string;
  kapasitasHarian: number;
  aktif: boolean;
  layanan: {
    id: string;
    kode: string;
    nama: string;
    aktif: boolean;
  };
}

describe('Manajemen Jadwal Layanan API (e2e)', () => {
  let app: INestApplication | undefined;
  let prisma: PrismaService | undefined;

  const unik = randomUUID().replace(/-/g, '').slice(0, 10).toUpperCase();

  const emailUser = `jadwal-user-${unik}@test.local`;
  const emailAdmin = `jadwal-admin-${unik}@test.local`;

  const kataSandi = 'RahasiaE2E123!';

  const kodeLayananSatu = `A${unik}`;
  const kodeLayananDua = `B${unik}`;

  const penggunaIds: string[] = [];

  let layananSatuId = '';
  let layananDuaId = '';
  let jadwalId = '';

  let tokenUser = '';
  let tokenAdmin = '';

  // ==========================================
  // HELPER
  // ==========================================

  function httpServer() {
    if (!app) {
      throw new Error('Aplikasi E2E belum siap');
    }

    return app.getHttpServer();
  }

  function database(): PrismaService {
    if (!prisma) {
      throw new Error('Prisma E2E belum siap');
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
      .send({
        nama,
        email,
        kataSandi,
      })
      .expect(201);

    const pengguna = registrasi.body as RegisterResponse;

    penggunaIds.push(pengguna.id);

    if (peran === PeranPengguna.ADMIN) {
      await database().pengguna.update({
        where: {
          id: pengguna.id,
        },
        data: {
          peran: PeranPengguna.ADMIN,
        },
      });
    }

    const login = await request(httpServer())
      .post('/api/v1/auth/login')
      .send({
        email,
        kataSandi,
        namaPerangkat: 'Jest E2E Jadwal',
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
      !['localhost', '127.0.0.1'].includes(url.hostname) ||
      url.port !== '5433'
    ) {
      throw new Error(
        'E2E hanya boleh menggunakan ' + 'capstone_antrean_test pada port 5433',
      );
    }

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();

    configureApp(app);

    await app.init();

    prisma = app.get(PrismaService);

    // Buat dua akun pengujian.
    tokenUser = await buatAkun(
      'User E2E Jadwal',
      emailUser,
      PeranPengguna.USER,
    );

    tokenAdmin = await buatAkun(
      'Admin E2E Jadwal',
      emailAdmin,
      PeranPengguna.ADMIN,
    );

    // Buat layanan khusus pengujian.
    // Tidak bergantung pada seed development.
    const layananSatu = await database().layanan.create({
      data: {
        kode: kodeLayananSatu,
        nama: 'Layanan E2E Jadwal Satu',
        deskripsi: 'Layanan pengujian jadwal',
        prefixAntrean: 'A',
        durasiDasarMenit: 15,
        aktif: true,
      },
    });

    layananSatuId = layananSatu.id;

    const layananDua = await database().layanan.create({
      data: {
        kode: kodeLayananDua,
        nama: 'Layanan E2E Jadwal Dua',
        deskripsi: 'Layanan pengujian jadwal',
        prefixAntrean: 'B',
        durasiDasarMenit: 10,
        aktif: true,
      },
    });

    layananDuaId = layananDua.id;
  });

  // ==========================================
  // CLEANUP
  // ==========================================

  afterAll(async () => {
    try {
      if (prisma) {
        const layananIds = [layananSatuId, layananDuaId].filter(Boolean);

        if (layananIds.length > 0) {
          await prisma.jadwalLayanan.deleteMany({
            where: {
              layananId: {
                in: layananIds,
              },
            },
          });

          await prisma.layanan.deleteMany({
            where: {
              id: {
                in: layananIds,
              },
            },
          });
        }

        if (penggunaIds.length > 0) {
          await prisma.sesiPengguna.deleteMany({
            where: {
              penggunaId: {
                in: penggunaIds,
              },
            },
          });

          await prisma.pengguna.deleteMany({
            where: {
              id: {
                in: penggunaIds,
              },
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
  // TEST 1 - JWT DAN RBAC
  // ==========================================

  it('menolak akses tanpa JWT dan operasi ADMIN oleh USER', async () => {
    const body = {
      layananId: layananSatuId,
      hari: HariLayanan.SABTU,
      jamBuka: '08:00',
      jamTutup: '12:00',
      kapasitasHarian: 50,
    };

    await request(httpServer()).get('/api/v1/jadwal-layanan').expect(401);

    await request(httpServer())
      .post('/api/v1/jadwal-layanan')
      .send(body)
      .expect(401);

    await request(httpServer())
      .post('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenUser}`)
      .send(body)
      .expect(403);
  });

  // ==========================================
  // TEST 2 - VALIDASI
  // ==========================================

  it('menolak input, jam, dan layanan yang tidak valid', async () => {
    await request(httpServer())
      .post('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        layananId: 'bukan-uuid',
        hari: 'HARI_INVALID',
        jamBuka: '25:00',
        jamTutup: 'tidak-valid',
        kapasitasHarian: -1,
      })
      .expect(400);

    await request(httpServer())
      .post('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        layananId: layananSatuId,
        hari: HariLayanan.SABTU,
        jamBuka: '15:00',
        jamTutup: '08:00',
        kapasitasHarian: 50,
      })
      .expect(400);

    const idTidakAda = '00000000-0000-4000-8000-000000000000';

    await request(httpServer())
      .post('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        layananId: idTidakAda,
        hari: HariLayanan.SABTU,
        jamBuka: '08:00',
        jamTutup: '12:00',
        kapasitasHarian: 50,
      })
      .expect(404);

    // Layanan nonaktif tidak boleh
    // dijadikan tempat membuat jadwal.
    await database().layanan.update({
      where: { id: layananDuaId },
      data: { aktif: false },
    });

    try {
      await request(httpServer())
        .post('/api/v1/jadwal-layanan')
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({
          layananId: layananDuaId,
          hari: HariLayanan.SABTU,
          jamBuka: '08:00',
          jamTutup: '12:00',
          kapasitasHarian: 50,
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
  // TEST 3 - CREATE DAN DUPLIKASI
  // ==========================================

  it('ADMIN membuat jadwal dan duplikasi menghasilkan 409', async () => {
    const body = {
      layananId: layananSatuId,
      hari: HariLayanan.SABTU,
      jamBuka: '08:00',
      jamTutup: '12:00',
      kapasitasHarian: 50,
    };

    const response = await request(httpServer())
      .post('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send(body)
      .expect(201);

    const jadwal = response.body as JadwalResponse;

    jadwalId = jadwal.id;

    expect(jadwal.layananId).toBe(layananSatuId);
    expect(jadwal.hari).toBe(HariLayanan.SABTU);
    expect(jadwal.kapasitasHarian).toBe(50);
    expect(jadwal.aktif).toBe(true);
    expect(jadwal.layanan.id).toBe(layananSatuId);

    // Format waktu Prisma.
    expect(jadwal.jamBuka).toContain('08:00:00');
    expect(jadwal.jamTutup).toContain('12:00:00');

    // Tidak boleh ada dua jadwal SABTU
    // untuk layanan yang sama.
    await request(httpServer())
      .post('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send(body)
      .expect(409);
  });

  // ==========================================
  // TEST 4 - READ ALL DAN READ ONE
  // ==========================================

  it('ADMIN dan USER dapat melihat jadwal aktif', async () => {
    const adminResponse = await request(httpServer())
      .get('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(200);

    const daftarAdmin = adminResponse.body as JadwalResponse[];

    expect(daftarAdmin.some((jadwal) => jadwal.id === jadwalId)).toBe(true);

    const userResponse = await request(httpServer())
      .get('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);

    const daftarUser = userResponse.body as JadwalResponse[];

    expect(daftarUser.some((jadwal) => jadwal.id === jadwalId)).toBe(true);

    const detail = await request(httpServer())
      .get(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);

    const jadwal = detail.body as JadwalResponse;

    expect(jadwal.id).toBe(jadwalId);
    expect(jadwal.hari).toBe(HariLayanan.SABTU);
  });

  // ==========================================
  // TEST 5 - UPDATE PARSIAL
  // ==========================================

  it('ADMIN mengubah jam dan kapasitas, USER ditolak', async () => {
    await request(httpServer())
      .patch(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .send({ kapasitasHarian: 200 })
      .expect(403);

    const response = await request(httpServer())
      .patch(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        jamTutup: '14:00',
        kapasitasHarian: 75,
      })
      .expect(200);

    const jadwal = response.body as JadwalResponse;

    expect(jadwal.kapasitasHarian).toBe(75);
    expect(jadwal.jamBuka).toContain('08:00:00');
    expect(jadwal.jamTutup).toContain('14:00:00');

    // PATCH dengan hanya jamBuka tetap
    // divalidasi terhadap jamTutup existing.
    await request(httpServer())
      .patch(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        jamBuka: '15:00',
      })
      .expect(400);

    await request(httpServer())
      .patch(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        kapasitasHarian: -10,
      })
      .expect(400);
  });

  // ==========================================
  // TEST 6 - UNIQUE PADA UPDATE
  // ==========================================

  it('menolak perubahan hari duplikat dan mendukung perpindahan layanan', async () => {
    // Jadwal SELASA pada layanan pertama.
    const responseCreate = await request(httpServer())
      .post('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        layananId: layananSatuId,
        hari: HariLayanan.SELASA,
        jamBuka: '09:00',
        jamTutup: '13:00',
        kapasitasHarian: 30,
      })
      .expect(201);

    const jadwalKedua = responseCreate.body as JadwalResponse;

    // Sudah ada jadwal SABTU pada layanan ini.
    await request(httpServer())
      .patch(`/api/v1/jadwal-layanan/${jadwalKedua.id}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        hari: HariLayanan.SABTU,
      })
      .expect(409);

    // Memindahkan jadwal SELASA ke layanan
    // kedua yang masih aktif.
    const responseUpdate = await request(httpServer())
      .patch(`/api/v1/jadwal-layanan/${jadwalKedua.id}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        layananId: layananDuaId,
      })
      .expect(200);

    const hasil = responseUpdate.body as JadwalResponse;

    expect(hasil.layananId).toBe(layananDuaId);
    expect(hasil.hari).toBe(HariLayanan.SELASA);
  });

  // ==========================================
  // TEST 7 - SOFT DELETE
  // ==========================================

  it('soft delete menyembunyikan jadwal dari USER', async () => {
    await request(httpServer())
      .delete(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(403);

    const response = await request(httpServer())
      .delete(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(200);

    const jadwal = response.body as JadwalResponse;

    expect(jadwal.aktif).toBe(false);

    // Pastikan data tetap ada di database.
    const databaseRecord = await database().jadwalLayanan.findUnique({
      where: { id: jadwalId },
    });

    expect(databaseRecord).not.toBeNull();
    expect(databaseRecord?.aktif).toBe(false);

    // USER tidak dapat membacanya.
    await request(httpServer())
      .get(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(404);

    const daftarResponse = await request(httpServer())
      .get('/api/v1/jadwal-layanan')
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);

    const daftar = daftarResponse.body as JadwalResponse[];

    expect(daftar.some((item) => item.id === jadwalId)).toBe(false);

    // ADMIN tetap bisa melihatnya.
    await request(httpServer())
      .get(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(200);
  });

  // ==========================================
  // TEST 8 - REAKTIVASI
  // ==========================================

  it('ADMIN dapat mengaktifkan kembali jadwal', async () => {
    const response = await request(httpServer())
      .patch(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        aktif: true,
      })
      .expect(200);

    const jadwal = response.body as JadwalResponse;

    expect(jadwal.aktif).toBe(true);

    await request(httpServer())
      .get(`/api/v1/jadwal-layanan/${jadwalId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);
  });

  // ==========================================
  // TEST 9 - LAYANAN INDUK NONAKTIF
  // ==========================================

  it('menyembunyikan jadwal jika layanan induk nonaktif', async () => {
    await database().layanan.update({
      where: { id: layananSatuId },
      data: { aktif: false },
    });

    try {
      // USER tidak dapat melihat jadwal.
      await request(httpServer())
        .get(`/api/v1/jadwal-layanan/${jadwalId}`)
        .set('Authorization', `Bearer ${tokenUser}`)
        .expect(404);

      const response = await request(httpServer())
        .get('/api/v1/jadwal-layanan')
        .set('Authorization', `Bearer ${tokenUser}`)
        .expect(200);

      const daftar = response.body as JadwalResponse[];

      expect(daftar.some((item) => item.id === jadwalId)).toBe(false);

      // Tidak boleh melakukan reaktivasi
      // saat layanan induk nonaktif.
      await request(httpServer())
        .patch(`/api/v1/jadwal-layanan/${jadwalId}`)
        .set('Authorization', `Bearer ${tokenAdmin}`)
        .send({
          aktif: true,
        })
        .expect(400);

      // ADMIN tetap dapat membaca jadwal.
      await request(httpServer())
        .get(`/api/v1/jadwal-layanan/${jadwalId}`)
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
  // TEST 10 - NOT FOUND DAN INVALID UUID
  // ==========================================

  it('mengembalikan 404 dan 400 untuk ID tidak valid', async () => {
    const idTidakAda = '00000000-0000-4000-8000-000000000000';

    await request(httpServer())
      .get(`/api/v1/jadwal-layanan/${idTidakAda}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(404);

    await request(httpServer())
      .patch(`/api/v1/jadwal-layanan/${idTidakAda}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({
        kapasitasHarian: 50,
      })
      .expect(404);

    await request(httpServer())
      .delete(`/api/v1/jadwal-layanan/${idTidakAda}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(404);

    await request(httpServer())
      .get('/api/v1/jadwal-layanan/bukan-uuid')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .expect(400);
  });
});
