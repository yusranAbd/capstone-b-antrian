import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { ThrottlerStorage } from '@nestjs/throttler';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { configureApp } from '../src/configure-app';

import {
  HariLayanan,
  PeranPengguna,
  StatusTiket,
} from '../src/generated/prisma/client';

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

interface TiketResponse {
  id: string;
  penggunaId: string;
  layananId: string;
  tanggalAntrean: string;
  nomorUrut: number;
  kodeTiket: string;
  status: StatusTiket;
}

interface AkunUji {
  id: string;
  token: string;
}

describe('Reservasi Antrean API (e2e)', () => {
  let app: INestApplication | undefined;
  let prisma: PrismaService | undefined;

  let admin!: AkunUji;
  let petugas!: AkunUji;
  let userA!: AkunUji;
  let userB!: AkunUji;
  let userC!: AkunUji;

  let layananUtamaId = '';
  let layananKapasitasId = '';
  let layananTanpaJadwalId = '';

  let tiketAwalId = '';

  const penggunaIds: string[] = [];
  const layananIds: string[] = [];

  const unik = randomUUID().replace(/-/g, '').slice(0, 10).toUpperCase();

  const kataSandi = 'RahasiaKhususE2E123!';

  const endpoint = '/api/v1/reservasi';

  const idTidakAda = '00000000-0000-4000-8000-000000000000';

  const semuaHari: HariLayanan[] = [
    HariLayanan.MINGGU,
    HariLayanan.SENIN,
    HariLayanan.SELASA,
    HariLayanan.RABU,
    HariLayanan.KAMIS,
    HariLayanan.JUMAT,
    HariLayanan.SABTU,
  ];

  // Tanggal selalu berada di masa depan.
  function tanggalMendatang(tambahHari: number): string {
    const tanggal = new Date();
    tanggal.setUTCDate(tanggal.getUTCDate() + tambahHari);

    return tanggal.toISOString().slice(0, 10);
  }

  const tanggalUtama = tanggalMendatang(30);
  const tanggalKapasitas = tanggalMendatang(31);
  const tanggalRace = tanggalMendatang(32);
  const tanggalDuplikatRace = tanggalMendatang(33);
  const tanggalNomorRace = tanggalMendatang(34);

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

  function bodyReservasi(layananId: string, tanggalAntrean: string) {
    return {
      layananId,
      tanggalAntrean,
    };
  }

  async function buatAkun(
    nama: string,
    peran: PeranPengguna,
  ): Promise<AkunUji> {
    const email = `reservasi-${randomUUID()}@test.local`;

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
        data: { peran },
      });
    }

    const login = await request(server())
      .post('/api/v1/auth/login')
      .send({
        email,
        kataSandi,
        namaPerangkat: 'Jest E2E Reservasi',
      })
      .expect(200);

    const hasilLogin = login.body as LoginResponse;

    expect(hasilLogin.user.peran).toBe(peran);

    return {
      id: hasilLogin.user.id,
      token: hasilLogin.accessToken,
    };
  }

  async function buatLayanan(
    kode: string,
    kapasitasHarian?: number,
  ): Promise<string> {
    const layanan = await db().layanan.create({
      data: {
        kode,
        nama: `Layanan E2E ${kode}`,
        deskripsi: 'Khusus pengujian reservasi',
        prefixAntrean: 'R',
        durasiDasarMenit: 10,
        aktif: true,
      },
    });

    layananIds.push(layanan.id);

    if (kapasitasHarian !== undefined) {
      const jamBuka = new Date('1970-01-01T08:00:00.000Z');

      const jamTutup = new Date('1970-01-01T15:00:00.000Z');

      await db().jadwalLayanan.createMany({
        data: semuaHari.map((hari) => ({
          layananId: layanan.id,
          hari,
          jamBuka,
          jamTutup,
          kapasitasHarian,
          aktif: true,
        })),
      });
    }

    return layanan.id;
  }

  // ==========================================
  // SETUP
  // ==========================================

  beforeAll(async () => {
    const databaseUrl = process.env.DATABASE_URL;

    if (!databaseUrl) {
      throw new Error('DATABASE_URL testing wajib diatur');
    }

    const url = new URL(databaseUrl);

    if (
      url.pathname !== '/capstone_antrean_test' ||
      !['127.0.0.1', 'localhost'].includes(url.hostname) ||
      url.port !== '5433'
    ) {
      throw new Error(
        'E2E hanya boleh berjalan pada ' +
          'capstone_antrean_test lokal port 5433',
      );
    }

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(ThrottlerStorage)
      .useValue({
        increment: async () =>
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

    // Akun khusus untuk E2E.
    admin = await buatAkun('Admin E2E Reservasi', PeranPengguna.ADMIN);

    petugas = await buatAkun('Petugas E2E Reservasi', PeranPengguna.PETUGAS);

    userA = await buatAkun('Pengguna Reservasi A', PeranPengguna.USER);

    userB = await buatAkun('Pengguna Reservasi B', PeranPengguna.USER);

    userC = await buatAkun('Pengguna Reservasi C', PeranPengguna.USER);

    // Layanan utama: kapasitas 10.
    layananUtamaId = await buatLayanan(`RU${unik}`, 10);

    // Layanan khusus kapasitas terakhir.
    layananKapasitasId = await buatLayanan(`RK${unik}`, 1);

    // Tidak dibuatkan jadwal.
    layananTanpaJadwalId = await buatLayanan(`RT${unik}`);
  }, 120000);

  // ==========================================
  // CLEANUP
  // ==========================================

  afterAll(async () => {
    try {
      if (prisma) {
        if (layananIds.length > 0) {
          await prisma.tiketAntrean.deleteMany({
            where: {
              layananId: {
                in: layananIds,
              },
            },
          });

          await prisma.urutanAntreanHarian.deleteMany({
            where: {
              layananId: {
                in: layananIds,
              },
            },
          });

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
  }, 30000);

  // ==========================================
  // TEST 1: AUTHENTICATION DAN RBAC
  // ==========================================

  it('menolak akses tanpa JWT, ADMIN, dan PETUGAS', async () => {
    const body = bodyReservasi(layananUtamaId, tanggalUtama);

    await request(server()).post(endpoint).send(body).expect(401);

    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${admin.token}`)
      .send(body)
      .expect(403);

    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${petugas.token}`)
      .send(body)
      .expect(403);

    await request(server())
      .get(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);
  });

  // ==========================================
  // TEST 2: VALIDASI INPUT
  // ==========================================

  it('menolak UUID, tanggal, dan layanan tidak valid', async () => {
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .send({
        layananId: 'bukan-uuid',
        tanggalAntrean: tanggalUtama,
      })
      .expect(400);

    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .send({
        layananId: layananUtamaId,
        tanggalAntrean: '2099-02-30',
      })
      .expect(400);

    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .send({
        layananId: layananUtamaId,
        tanggalAntrean: '2020-01-01',
      })
      .expect(400);

    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .send(bodyReservasi(idTidakAda, tanggalUtama))
      .expect(404);
  });

  // ==========================================
  // TEST 3: LAYANAN NONAKTIF
  // ==========================================

  it('menolak layanan nonaktif', async () => {
    await db().layanan.update({
      where: { id: layananUtamaId },
      data: { aktif: false },
    });

    try {
      await request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${userA.token}`)
        .send(bodyReservasi(layananUtamaId, tanggalUtama))
        .expect(400);
    } finally {
      await db().layanan.update({
        where: { id: layananUtamaId },
        data: { aktif: true },
      });
    }
  });

  // ==========================================
  // TEST 4: VALIDASI JADWAL
  // ==========================================

  it('menolak layanan tanpa jadwal atau jadwal nonaktif', async () => {
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .send(bodyReservasi(layananTanpaJadwalId, tanggalUtama))
      .expect(400);

    const hari =
      semuaHari[new Date(`${tanggalUtama}T00:00:00.000Z`).getUTCDay()];

    const where = {
      layananId_hari: {
        layananId: layananUtamaId,
        hari,
      },
    };

    await db().jadwalLayanan.update({
      where,
      data: { aktif: false },
    });

    try {
      await request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${userA.token}`)
        .send(bodyReservasi(layananUtamaId, tanggalUtama))
        .expect(400);
    } finally {
      await db().jadwalLayanan.update({
        where,
        data: { aktif: true },
      });
    }
  });

  // ==========================================
  // TEST 5: CREATE RESERVASI
  // ==========================================

  it('USER berhasil membuat tiket DIPESAN', async () => {
    const response = await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .send(bodyReservasi(layananUtamaId, tanggalUtama))
      .expect(201);

    const tiket = response.body as TiketResponse;

    tiketAwalId = tiket.id;

    expect(tiket.penggunaId).toBe(userA.id);
    expect(tiket.layananId).toBe(layananUtamaId);
    expect(tiket.nomorUrut).toBe(1);
    expect(tiket.status).toBe(StatusTiket.DIPESAN);
    expect(tiket.kodeTiket).toMatch(/^TK[A-F0-9]{24}$/);

    const tersimpan = await db().tiketAntrean.findUnique({
      where: { id: tiket.id },
    });

    expect(tersimpan).not.toBeNull();
    expect(tersimpan?.nomorUrut).toBe(1);
  });

  // ==========================================
  // TEST 6: DUPLIKASI DAN ROLLBACK
  // ==========================================

  it('menolak duplikasi tanpa menaikkan counter', async () => {
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .send(bodyReservasi(layananUtamaId, tanggalUtama))
      .expect(409);

    const counter = await db().urutanAntreanHarian.findUnique({
      where: {
        layananId_tanggal: {
          layananId: layananUtamaId,
          tanggal: new Date(`${tanggalUtama}T00:00:00.000Z`),
        },
      },
    });

    expect(counter?.nomorTerakhir).toBe(1);
  });

  // ==========================================
  // TEST 7: READ DAN KEPEMILIKAN
  // ==========================================

  it('USER hanya dapat membaca tiket miliknya', async () => {
    const response = await request(server())
      .get(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    const daftar = response.body as TiketResponse[];

    expect(daftar.some((tiket) => tiket.id === tiketAwalId)).toBe(true);

    const detail = await request(server())
      .get(`${endpoint}/${tiketAwalId}`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    expect((detail.body as TiketResponse).id).toBe(tiketAwalId);

    await request(server())
      .get(`${endpoint}/${tiketAwalId}`)
      .set('Authorization', `Bearer ${userB.token}`)
      .expect(404);

    await request(server())
      .get(`${endpoint}/bukan-uuid`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(400);

    await request(server())
      .get(`${endpoint}/${idTidakAda}`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(404);
  });

  // ==========================================
  // TEST 8: NOMOR UNIK DALAM SATU HARI
  // ==========================================

  it('pengguna kedua mendapat nomor berbeda', async () => {
    const response = await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userB.token}`)
      .send(bodyReservasi(layananUtamaId, tanggalUtama))
      .expect(201);

    const tiket = response.body as TiketResponse;

    expect(tiket.nomorUrut).toBe(2);
    expect(tiket.penggunaId).toBe(userB.id);

    const tiketDatabase = await db().tiketAntrean.findMany({
      where: {
        layananId: layananUtamaId,
        tanggalAntrean: new Date(`${tanggalUtama}T00:00:00.000Z`),
      },
      orderBy: { nomorUrut: 'asc' },
    });

    expect(tiketDatabase.map((item) => item.nomorUrut)).toEqual([1, 2]);
  });

  // ==========================================
  // TEST 9: KAPASITAS PENUH
  // ==========================================

  it('menolak reservasi jika kapasitas satu sudah penuh', async () => {
    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userA.token}`)
      .send(bodyReservasi(layananKapasitasId, tanggalKapasitas))
      .expect(201);

    await request(server())
      .post(endpoint)
      .set('Authorization', `Bearer ${userB.token}`)
      .send(bodyReservasi(layananKapasitasId, tanggalKapasitas))
      .expect(409);

    const jumlah = await db().tiketAntrean.count({
      where: {
        layananId: layananKapasitasId,
        tanggalAntrean: new Date(`${tanggalKapasitas}T00:00:00.000Z`),
      },
    });

    expect(jumlah).toBe(1);
  });

  // ==========================================
  // TEST 10: RACE CONDITION SLOT TERAKHIR
  // ==========================================

  it('dua pengguna bersamaan tidak dapat mengambil slot terakhir yang sama', async () => {
    const body = bodyReservasi(layananKapasitasId, tanggalRace);

    const [responseA, responseB] = await Promise.all([
      request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${userB.token}`)
        .send(body),

      request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${userC.token}`)
        .send(body),
    ]);

    const status = [responseA.status, responseB.status].sort((a, b) => a - b);

    expect(status).toEqual([201, 409]);

    const tanggal = new Date(`${tanggalRace}T00:00:00.000Z`);

    const jumlah = await db().tiketAntrean.count({
      where: {
        layananId: layananKapasitasId,
        tanggalAntrean: tanggal,
      },
    });

    expect(jumlah).toBe(1);

    const counter = await db().urutanAntreanHarian.findUnique({
      where: {
        layananId_tanggal: {
          layananId: layananKapasitasId,
          tanggal,
        },
      },
    });

    expect(counter?.nomorTerakhir).toBe(1);
  }, 30000);

  // ==========================================
  // TEST 11: REQUEST GANDA PENGGUNA SAMA
  // ==========================================

  it('dua request bersamaan dari USER yang sama hanya menghasilkan satu tiket', async () => {
    const body = bodyReservasi(layananUtamaId, tanggalDuplikatRace);

    const [responseA, responseB] = await Promise.all([
      request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${userA.token}`)
        .send(body),

      request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${userA.token}`)
        .send(body),
    ]);

    const status = [responseA.status, responseB.status].sort((a, b) => a - b);

    expect(status).toEqual([201, 409]);

    const jumlah = await db().tiketAntrean.count({
      where: {
        penggunaId: userA.id,
        layananId: layananUtamaId,
        tanggalAntrean: new Date(`${tanggalDuplikatRace}T00:00:00.000Z`),
      },
    });

    expect(jumlah).toBe(1);
  }, 30000);

  // ==========================================
  // TEST 12: NOMOR UNIK REQUEST BERSAMAAN
  // ==========================================

  it('dua pengguna bersamaan mendapatkan nomor urut berbeda', async () => {
    const body = bodyReservasi(layananUtamaId, tanggalNomorRace);

    const [responseB, responseC] = await Promise.all([
      request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${userB.token}`)
        .send(body),

      request(server())
        .post(endpoint)
        .set('Authorization', `Bearer ${userC.token}`)
        .send(body),
    ]);

    expect(responseB.status).toBe(201);
    expect(responseC.status).toBe(201);

    const tiketB = responseB.body as TiketResponse;
    const tiketC = responseC.body as TiketResponse;

    const nomor = [tiketB.nomorUrut, tiketC.nomorUrut].sort((a, b) => a - b);

    expect(nomor).toEqual([1, 2]);

    expect(tiketB.kodeTiket).not.toBe(tiketC.kodeTiket);
  }, 30000);
});
