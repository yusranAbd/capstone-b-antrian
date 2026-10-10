import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { configureApp } from '../src/configure-app';
import { PeranPengguna } from '../src/generated/prisma/client';
import { PrismaService } from '../src/prisma/prisma.service';
import { ThrottlerStorage } from '@nestjs/throttler';

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

interface PenugasanResponse {
  id: string;
  petugasId: string;
  loketId: string;
  tanggalMulai: string;
  tanggalSelesai: string | null;
  aktif: boolean;
  petugas: {
    id: string;
    peran: PeranPengguna;
  };
  loket: {
    id: string;
    aktif: boolean;
  };
}

describe('Penugasan Petugas API (e2e)', () => {
  let app: INestApplication | undefined;
  let prisma: PrismaService | undefined;

  const unik = randomUUID().replace(/-/g, '').slice(0, 10);

  const kataSandi = 'RahasiaE2E123!';

  const penggunaIds: string[] = [];
  const loketIds: string[] = [];

  let adminId = '';
  let petugasId = '';
  let petugasDuaId = '';
  let userId = '';

  let adminToken = '';
  let petugasToken = '';
  let petugasDuaToken = '';
  let userToken = '';

  let layananId = '';
  let loketSatuId = '';
  let loketDuaId = '';

  let penugasanSatuId = '';
  let penugasanDuaId = '';
  let penugasanTigaId = '';

  const idTidakAda = '00000000-0000-4000-8000-000000000000';

  const endpoint = '/api/v1/penugasan-petugas';

  function server() {
    if (!app) {
      throw new Error('Aplikasi E2E belum siap');
    }

    return app.getHttpServer();
  }

  function db(): PrismaService {
    if (!prisma) {
      throw new Error('Prisma E2E belum siap');
    }

    return prisma;
  }

  async function buatAkun(
    nama: string,
    peran: PeranPengguna,
  ): Promise<{ id: string; token: string }> {
    const email = `${peran.toLowerCase()}-${randomUUID()}@test.local`;

    const registrasi = await request(server())
      .post('/api/v1/auth/register')
      .send({
        nama,
        email,
        kataSandi,
      })
      .expect(201);

    const hasilRegistrasi = registrasi.body as RegisterResponse;

    penggunaIds.push(hasilRegistrasi.id);

    if (peran !== PeranPengguna.USER) {
      await db().pengguna.update({
        where: {
          id: hasilRegistrasi.id,
        },
        data: {
          peran,
        },
      });
    }

    const login = await request(server())
      .post('/api/v1/auth/login')
      .send({
        email,
        kataSandi,
        namaPerangkat: 'Jest E2E Penugasan',
      })
      .expect(200);

    const hasilLogin = login.body as LoginResponse;

    expect(hasilLogin.user.peran).toBe(peran);

    return {
      id: hasilLogin.user.id,
      token: hasilLogin.accessToken,
    };
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
        'E2E hanya boleh menggunakan ' +
          'capstone_antrean_test lokal port 5433',
      );
    }

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(ThrottlerStorage)
      .useValue({
        increment: () =>
          Promise.resolve({
            totalHits: 1,
            timeToExpire: 60000,
            isBlocked: false,
            timeToBlockExpire: 0,
          }),
      })
      .compile();

    app = moduleRef.createNestApplication();

    configureApp(app);

    await app.init();

    prisma = app.get(PrismaService);

    // Buat akun pengujian terpisah.
    const admin = await buatAkun('Admin E2E Penugasan', PeranPengguna.ADMIN);

    adminId = admin.id;
    adminToken = admin.token;

    const petugas = await buatAkun('Petugas E2E Satu', PeranPengguna.PETUGAS);

    petugasId = petugas.id;
    petugasToken = petugas.token;

    const petugasDua = await buatAkun('Petugas E2E Dua', PeranPengguna.PETUGAS);

    petugasDuaId = petugasDua.id;
    petugasDuaToken = petugasDua.token;

    const pengguna = await buatAkun('User E2E Penugasan', PeranPengguna.USER);

    userId = pengguna.id;
    userToken = pengguna.token;

    // Buat layanan khusus testing.
    const layanan = await db().layanan.create({
      data: {
        kode: `P${unik}`,
        nama: 'Layanan E2E Penugasan',
        deskripsi: 'Data khusus pengujian',
        prefixAntrean: 'P',
        durasiDasarMenit: 15,
        aktif: true,
      },
    });

    layananId = layanan.id;

    // Buat dua loket.
    const loketSatu = await db().loket.create({
      data: {
        layananId,
        kode: 'LKT-P1',
        nama: 'Loket E2E Satu',
        lokasi: 'Ruang Pengujian',
        aktif: true,
      },
    });

    loketSatuId = loketSatu.id;
    loketIds.push(loketSatu.id);

    const loketDua = await db().loket.create({
      data: {
        layananId,
        kode: 'LKT-P2',
        nama: 'Loket E2E Dua',
        lokasi: 'Ruang Pengujian',
        aktif: true,
      },
    });

    loketDuaId = loketDua.id;
    loketIds.push(loketDua.id);
  }, 60000);

  // ==========================================
  // CLEANUP DATA KHUSUS E2E
  // ==========================================

  afterAll(async () => {
    try {
      if (prisma) {
        if (penggunaIds.length > 0 || loketIds.length > 0) {
          await prisma.penugasanPetugas.deleteMany({
            where: {
              OR: [
                {
                  petugasId: {
                    in: penggunaIds,
                  },
                },
                {
                  loketId: {
                    in: loketIds,
                  },
                },
              ],
            },
          });
        }

        if (loketIds.length > 0) {
          await prisma.loket.deleteMany({
            where: {
              id: { in: loketIds },
            },
          });
        }

        if (layananId) {
          await prisma.layanan.delete({
            where: {
              id: layananId,
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
  }, 30000);

  // ==========================================
  // TEST 1 - AUTHENTICATION DAN RBAC
  // ==========================================

  it('menolak akses tanpa JWT dan akses USER', async () => {
    const body = {
      petugasId,
      loketId: loketSatuId,
      tanggalMulai: '2026-10-12',
      tanggalSelesai: '2026-10-16',
    };

    await request(server()).get(endpoint).expect(401);

    await request(server()).post(endpoint).send(body).expect(401);

    await request(server())
      .get(endpoint)
      .set('Authorization', `Bearer ${userToken}`)
      .expect(403);

    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${petugasToken}`)
      .send(body)
      .expect(403);
  });

  // ==========================================
  // TEST 2 - VALIDASI DATA
  // ==========================================

  it('menolak input, tanggal, dan peran tidak valid', async () => {
    const body = {
      petugasId,
      loketId: loketSatuId,
      tanggalMulai: '2026-10-12',
      tanggalSelesai: '2026-10-16',
    };

    // UUID tidak valid.
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        ...body,
        petugasId: 'bukan-uuid',
      })
      .expect(400);

    // Tanggal kalender tidak valid.
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        ...body,
        tanggalMulai: '2026-02-30',
      })
      .expect(400);

    // Tanggal selesai sebelum mulai.
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        ...body,
        tanggalMulai: '2026-10-20',
      })
      .expect(400);

    // USER tidak boleh ditugaskan.
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        ...body,
        petugasId: userId,
      })
      .expect(400);

    // Petugas tidak ditemukan.
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        ...body,
        petugasId: idTidakAda,
      })
      .expect(404);
  }, 60000);

  // ==========================================
  // TEST 3 - VALIDASI LOKET
  // ==========================================

  it('menolak penugasan pada loket nonaktif', async () => {
    await db().loket.update({
      where: { id: loketDuaId },
      data: { aktif: false },
    });

    try {
      await request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          petugasId,
          loketId: loketDuaId,
          tanggalMulai: '2026-10-12',
          tanggalSelesai: '2026-10-16',
        })
        .expect(400);
    } finally {
      await db().loket.update({
        where: { id: loketDuaId },
        data: { aktif: true },
      });
    }
  });

  // ==========================================
  // TEST 4 - CREATE PENUGASAN
  // ==========================================

  it('ADMIN berhasil membuat penugasan', async () => {
    const response = await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        petugasId,
        loketId: loketSatuId,
        tanggalMulai: '2026-10-12',
        tanggalSelesai: '2026-10-16',
      })
      .expect(201);

    const hasil = response.body as PenugasanResponse;

    penugasanSatuId = hasil.id;

    expect(hasil.petugasId).toBe(petugasId);
    expect(hasil.loketId).toBe(loketSatuId);
    expect(hasil.aktif).toBe(true);
    expect(hasil.petugas.peran).toBe(PeranPengguna.PETUGAS);

    const tersimpan = await db().penugasanPetugas.findUnique({
      where: { id: penugasanSatuId },
    });

    expect(tersimpan).not.toBeNull();
  });

  // ==========================================
  // TEST 5 - KONFLIK PERIODE
  // ==========================================

  it('menolak periode bertabrakan termasuk tanggal batas', async () => {
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        petugasId,
        loketId: loketDuaId,
        tanggalMulai: '2026-10-14',
        tanggalSelesai: '2026-10-18',
      })
      .expect(409);

    // Tanggal 16 masih termasuk periode awal.
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        petugasId,
        loketId: loketDuaId,
        tanggalMulai: '2026-10-16',
        tanggalSelesai: '2026-10-18',
      })
      .expect(409);
  });

  // ==========================================
  // TEST 6 - PERIODE TIDAK BERTABRAKAN
  // ==========================================

  it('mengizinkan periode berbeda untuk petugas sama', async () => {
    const response = await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        petugasId,
        loketId: loketDuaId,
        tanggalMulai: '2026-10-17',
        tanggalSelesai: '2026-10-19',
      })
      .expect(201);

    penugasanDuaId = (response.body as PenugasanResponse).id;

    expect(penugasanDuaId).toBeTruthy();
  });

  // ==========================================
  // TEST 7 - DUA PETUGAS PADA SATU LOKET
  // ==========================================

  it('mengizinkan petugas berbeda pada loket sama', async () => {
    const response = await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        petugasId: petugasDuaId,
        loketId: loketSatuId,
        tanggalMulai: '2026-10-14',
        tanggalSelesai: '2026-10-18',
      })
      .expect(201);

    const hasil = response.body as PenugasanResponse;

    penugasanTigaId = hasil.id;

    expect(hasil.petugasId).toBe(petugasDuaId);
    expect(hasil.loketId).toBe(loketSatuId);
  });

  // ==========================================
  // TEST 8 - READ DAN HAK AKSES
  // ==========================================

  it('ADMIN melihat semua, PETUGAS hanya miliknya', async () => {
    const responseAdmin = await request(server())
      .get(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    const daftarAdmin = responseAdmin.body as PenugasanResponse[];

    expect(daftarAdmin.some((item) => item.id === penugasanSatuId)).toBe(true);

    expect(daftarAdmin.some((item) => item.id === penugasanTigaId)).toBe(true);

    const responsePetugas = await request(server())
      .get(endpoint)
      .set('Authorization', `Bearer ${petugasToken}`)
      .expect(200);

    const daftarPetugas = responsePetugas.body as PenugasanResponse[];

    expect(daftarPetugas.every((item) => item.petugasId === petugasId)).toBe(
      true,
    );

    expect(daftarPetugas.some((item) => item.id === penugasanSatuId)).toBe(
      true,
    );

    const responsePetugasDua = await request(server())
      .get(endpoint)
      .set('Authorization', `Bearer ${petugasDuaToken}`)
      .expect(200);

    const daftarPetugasDua = responsePetugasDua.body as PenugasanResponse[];

    expect(
      daftarPetugasDua.every((item) => item.petugasId === petugasDuaId),
    ).toBe(true);

    // Petugas pertama tidak dapat membuka
    // penugasan milik petugas kedua.
    await request(server())
      .get(`${endpoint}/${penugasanTigaId}`)
      .set('Authorization', `Bearer ${petugasToken}`)
      .expect(404);

    // ADMIN dapat membuka semua detail.
    await request(server())
      .get(`${endpoint}/${penugasanTigaId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
  });

  // ==========================================
  // TEST 9 - UPDATE PENUGASAN
  // ==========================================

  it('memvalidasi update periode penugasan', async () => {
    await request(server())
      .patch(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${petugasToken}`)
      .send({
        tanggalSelesai: '2026-10-15',
      })
      .expect(403);

    // Perpendek periode pertama.
    const response = await request(server())
      .patch(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        tanggalSelesai: '2026-10-15',
      })
      .expect(200);

    const hasil = response.body as PenugasanResponse;

    expect(hasil.tanggalSelesai).toContain('2026-10-15');

    // Rentang tidak valid.
    await request(server())
      .patch(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        tanggalMulai: '2026-10-25',
        tanggalSelesai: '2026-10-20',
      })
      .expect(400);

    // Bentrok dengan penugasan kedua.
    await request(server())
      .patch(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        tanggalSelesai: '2026-10-18',
      })
      .expect(409);
  });

  // ==========================================
  // TEST 10 - SOFT DELETE DAN REAKTIVASI
  // ==========================================

  it('soft delete dan reaktivasi memeriksa konflik', async () => {
    await request(server())
      .delete(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${petugasToken}`)
      .expect(403);

    const hasilDelete = await request(server())
      .delete(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect((hasilDelete.body as PenugasanResponse).aktif).toBe(false);

    const record = await db().penugasanPetugas.findUnique({
      where: { id: penugasanSatuId },
    });

    expect(record).not.toBeNull();
    expect(record?.aktif).toBe(false);

    // Karena penugasan pertama nonaktif,
    // periode 13-15 dapat digunakan kembali.
    const penugasanBaru = await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        petugasId,
        loketId: loketDuaId,
        tanggalMulai: '2026-10-13',
        tanggalSelesai: '2026-10-15',
      })
      .expect(201);

    const idBaru = (penugasanBaru.body as PenugasanResponse).id;

    // Mengaktifkan penugasan pertama
    // sekarang harus ditolak karena konflik.
    await request(server())
      .patch(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ aktif: true })
      .expect(409);

    // Hentikan penugasan baru.
    await request(server())
      .delete(`${endpoint}/${idBaru}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    // Reaktivasi penugasan pertama berhasil.
    const reaktivasi = await request(server())
      .patch(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ aktif: true })
      .expect(200);

    expect((reaktivasi.body as PenugasanResponse).aktif).toBe(true);
  });

  // ==========================================
  // TEST 11 - TANGGAL SELESAI NULL
  // ==========================================

  it('mendukung penugasan tanpa tanggal akhir', async () => {
    // Hentikan penugasan kedua agar
    // periode terbuka tidak bertabrakan.
    await request(server())
      .delete(`${endpoint}/${penugasanDuaId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    const response = await request(server())
      .patch(`${endpoint}/${penugasanSatuId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ tanggalSelesai: null })
      .expect(200);

    expect((response.body as PenugasanResponse).tanggalSelesai).toBeNull();
  });

  // ==========================================
  // TEST 12 - ID TIDAK VALID
  // ==========================================

  it('mengembalikan 400 dan 404 untuk ID tidak valid', async () => {
    await request(server())
      .get(`${endpoint}/bukan-uuid`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(400);

    await request(server())
      .get(`${endpoint}/${idTidakAda}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(404);

    await request(server())
      .patch(`${endpoint}/${idTidakAda}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ aktif: false })
      .expect(404);

    await request(server())
      .delete(`${endpoint}/${idTidakAda}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(404);

    expect(adminId).toBeTruthy();
  });
});
