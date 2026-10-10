import { randomBytes, randomUUID } from 'node:crypto';
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

// ==========================================
// INTERFACE PENGUJIAN
// ==========================================

interface AkunUji {
  id: string;
  token: string;
}

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

interface ReservasiResponse {
  id: string;
  penggunaId: string;
  layananId: string;
  nomorUrut: number;
}

interface TiketResponse {
  id: string;
  penggunaId: string;
  layananId: string;
  tanggalAntrean: string;
  nomorUrut: number;
  nomorAntrean: string;
  tanggalPelayanan: string;
  kodeTiket: string;
  status: StatusTiket;
  layanan: {
    id: string;
    kode: string;
    nama: string;
    prefixAntrean: string;
  };
}

// ==========================================
// E2E TIKET DIGITAL
// ==========================================

describe('Tiket Antrean Digital API (e2e)', () => {
  let app: INestApplication | undefined;
  let prisma: PrismaService | undefined;

  let admin!: AkunUji;
  let petugas!: AkunUji;
  let userA!: AkunUji;
  let userB!: AkunUji;

  let layananId = '';
  let tiketAId = '';
  let tiketBId = '';
  let tiketBesarId = '';

  const penggunaIds: string[] = [];

  const unik = randomUUID().replace(/-/g, '').slice(0, 10).toUpperCase();

  const kataSandi = 'RahasiaE2ETiket123!';

  const endpoint = '/api/v1/tiket';

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

  function tanggalMendatang(tambahHari: number) {
    const tanggal = new Date();

    tanggal.setUTCDate(tanggal.getUTCDate() + tambahHari);

    return tanggal.toISOString().slice(0, 10);
  }

  const tanggalUtama = tanggalMendatang(40);
  const tanggalBesar = tanggalMendatang(41);

  function tanggalDatabase(value: string) {
    return new Date(`${value}T00:00:00.000Z`);
  }

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

  // ==========================================
  // HELPER PEMBUATAN AKUN
  // ==========================================

  async function buatAkun(
    nama: string,
    peran: PeranPengguna,
  ): Promise<AkunUji> {
    const email = `tiket-${randomUUID()}@test.local`;

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
        namaPerangkat: 'Jest E2E Tiket',
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
  // SETUP
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
        'E2E hanya boleh menggunakan database ' +
          'capstone_antrean_test lokal pada port 5433',
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

    // Membuat akun khusus E2E.
    admin = await buatAkun('Admin E2E Tiket', PeranPengguna.ADMIN);

    petugas = await buatAkun('Petugas E2E Tiket', PeranPengguna.PETUGAS);

    userA = await buatAkun('Pengguna Tiket A', PeranPengguna.USER);

    userB = await buatAkun('Pengguna Tiket B', PeranPengguna.USER);

    // Membuat layanan khusus pengujian.
    const layanan = await db().layanan.create({
      data: {
        kode: `TD${unik}`,
        nama: 'Layanan E2E Tiket Digital',
        deskripsi: 'Khusus pengujian E2E',
        prefixAntrean: 'A',
        durasiDasarMenit: 15,
        aktif: true,
      },
    });

    layananId = layanan.id;

    // Semua hari aktif agar pengujian
    // tidak bergantung pada hari tertentu.
    await db().jadwalLayanan.createMany({
      data: semuaHari.map((hari) => ({
        layananId,
        hari,
        jamBuka: new Date('1970-01-01T08:00:00.000Z'),
        jamTutup: new Date('1970-01-01T15:00:00.000Z'),
        kapasitasHarian: 20,
        aktif: true,
      })),
    });

    // USER A membuat reservasi pertama.
    const reservasiA = await request(server())
      .post('/api/v1/reservasi')
      .set('Authorization', `Bearer ${userA.token}`)
      .send({
        layananId,
        tanggalAntrean: tanggalUtama,
      })
      .expect(201);

    const tiketA = reservasiA.body as ReservasiResponse;

    tiketAId = tiketA.id;

    expect(tiketA.nomorUrut).toBe(1);

    // USER B membuat reservasi kedua.
    const reservasiB = await request(server())
      .post('/api/v1/reservasi')
      .set('Authorization', `Bearer ${userB.token}`)
      .send({
        layananId,
        tanggalAntrean: tanggalUtama,
      })
      .expect(201);

    const tiketB = reservasiB.body as ReservasiResponse;

    tiketBId = tiketB.id;

    expect(tiketB.nomorUrut).toBe(2);

    // Tambahkan hash QR internal untuk
    // memastikan tidak bocor ke API tiket.
    await db().tiketAntrean.update({
      where: {
        id: tiketAId,
      },
      data: {
        tokenQrHash: 'hash-internal-jangan-ditampilkan',
      },
    });

    // Siapkan counter konsisten untuk
    // tiket contoh dengan nomor 1000.
    await db().urutanAntreanHarian.create({
      data: {
        layananId,
        tanggal: tanggalDatabase(tanggalBesar),
        nomorTerakhir: 1000,
      },
    });

    // Fixture nomor besar untuk menguji
    // formatter, bukan alokasi nomor.
    const tiketBesar = await db().tiketAntrean.create({
      data: {
        pengguna: {
          connect: {
            id: userA.id,
          },
        },
        layanan: {
          connect: {
            id: layananId,
          },
        },
        tanggalAntrean: tanggalDatabase(tanggalBesar),
        nomorUrut: 1000,
        kodeTiket: `TK${randomBytes(12).toString('hex').toUpperCase()}`,
        status: StatusTiket.DIPESAN,
      },
    });

    tiketBesarId = tiketBesar.id;
  }, 120000);

  // ==========================================
  // CLEANUP
  // ==========================================

  afterAll(async () => {
    try {
      if (prisma) {
        if (layananId) {
          await prisma.tiketAntrean.deleteMany({
            where: {
              layananId,
            },
          });

          await prisma.urutanAntreanHarian.deleteMany({
            where: {
              layananId,
            },
          });

          await prisma.jadwalLayanan.deleteMany({
            where: {
              layananId,
            },
          });

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
  }, 60000);

  // ==========================================
  // TEST 1: TANPA JWT
  // ==========================================

  it('menolak akses daftar dan detail tanpa JWT', async () => {
    await request(server()).get(`${endpoint}/saya`).expect(401);

    await request(server()).get(`${endpoint}/${tiketAId}`).expect(401);
  });

  // ==========================================
  // TEST 2: RBAC
  // ==========================================

  it('menolak ADMIN dan PETUGAS pada endpoint USER', async () => {
    for (const akun of [admin, petugas]) {
      await request(server())
        .get(`${endpoint}/saya`)
        .set('Authorization', `Bearer ${akun.token}`)
        .expect(403);

      await request(server())
        .get(`${endpoint}/${tiketAId}`)
        .set('Authorization', `Bearer ${akun.token}`)
        .expect(403);
    }
  });

  // ==========================================
  // TEST 3: DAFTAR USER A
  // ==========================================

  it('USER A hanya melihat daftar tiket miliknya', async () => {
    const response = await request(server())
      .get(`${endpoint}/saya`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    const daftar = response.body as TiketResponse[];

    expect(daftar).toHaveLength(2);

    expect(daftar.every((tiket) => tiket.penggunaId === userA.id)).toBe(true);

    expect(daftar.some((tiket) => tiket.id === tiketAId)).toBe(true);

    expect(daftar.some((tiket) => tiket.id === tiketBesarId)).toBe(true);

    expect(daftar.some((tiket) => tiket.id === tiketBId)).toBe(false);
  });

  // ==========================================
  // TEST 4: DAFTAR USER B
  // ==========================================

  it('USER B hanya melihat tiket miliknya', async () => {
    const response = await request(server())
      .get(`${endpoint}/saya`)
      .set('Authorization', `Bearer ${userB.token}`)
      .expect(200);

    const daftar = response.body as TiketResponse[];

    expect(daftar).toHaveLength(1);

    expect(daftar[0].id).toBe(tiketBId);
    expect(daftar[0].penggunaId).toBe(userB.id);
    expect(daftar[0].nomorAntrean).toBe('A-002');
  });

  // ==========================================
  // TEST 5: DETAIL A-001
  // ==========================================

  it('berhasil menampilkan detail tiket A-001', async () => {
    const response = await request(server())
      .get(`${endpoint}/${tiketAId}`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    const tiket = response.body as TiketResponse;

    expect(tiket.id).toBe(tiketAId);
    expect(tiket.penggunaId).toBe(userA.id);

    expect(tiket.nomorUrut).toBe(1);
    expect(tiket.nomorAntrean).toBe('A-001');

    expect(tiket.status).toBe(StatusTiket.DIPESAN);

    expect(tiket.layanan.prefixAntrean).toBe('A');
  });

  // ==========================================
  // TEST 6: DETAIL A-002
  // ==========================================

  it('berhasil menampilkan detail tiket A-002', async () => {
    const response = await request(server())
      .get(`${endpoint}/${tiketBId}`)
      .set('Authorization', `Bearer ${userB.token}`)
      .expect(200);

    const tiket = response.body as TiketResponse;

    expect(tiket.id).toBe(tiketBId);
    expect(tiket.nomorUrut).toBe(2);
    expect(tiket.nomorAntrean).toBe('A-002');

    expect(tiket.status).toBe(StatusTiket.DIPESAN);
  });

  // ==========================================
  // TEST 7: NOMOR LEBIH DARI 999
  // ==========================================

  it('memformat nomor 1000 sebagai A-1000', async () => {
    const response = await request(server())
      .get(`${endpoint}/${tiketBesarId}`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    const tiket = response.body as TiketResponse;

    expect(tiket.nomorUrut).toBe(1000);
    expect(tiket.nomorAntrean).toBe('A-1000');
  });

  // ==========================================
  // TEST 8: FORMAT TANGGAL DAN STATUS
  // ==========================================

  it('menghasilkan tanggal YYYY-MM-DD dan status benar', async () => {
    const response = await request(server())
      .get(`${endpoint}/${tiketAId}`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    const tiket = response.body as TiketResponse;

    expect(tiket.tanggalPelayanan).toBe(tanggalUtama);

    expect(tiket.tanggalPelayanan).toMatch(/^\d{4}-\d{2}-\d{2}$/);

    expect(tiket.tanggalAntrean).toBe(`${tanggalUtama}T00:00:00.000Z`);

    expect(tiket.status).toBe(StatusTiket.DIPESAN);
  });

  // ==========================================
  // TEST 9: PRIVASI TOKEN QR
  // ==========================================

  it('tidak menampilkan hash QR internal', async () => {
    const response = await request(server())
      .get(`${endpoint}/${tiketAId}`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    expect(response.body).not.toHaveProperty('tokenQrHash');

    expect(response.body).not.toHaveProperty('qrKedaluwarsaPada');

    const daftar = await request(server())
      .get(`${endpoint}/saya`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    const tiket = daftar.body as TiketResponse[];

    for (const item of tiket) {
      expect(item).not.toHaveProperty('tokenQrHash');
    }

    // Hash memang ada di database,
    // tetapi tidak diekspos oleh API.
    const record = await db().tiketAntrean.findUnique({
      where: {
        id: tiketAId,
      },
    });

    expect(record?.tokenQrHash).toBe('hash-internal-jangan-ditampilkan');
  });

  // ==========================================
  // TEST 10: KEPEMILIKAN TIKET
  // ==========================================

  it('USER tidak dapat membuka tiket milik USER lain', async () => {
    await request(server())
      .get(`${endpoint}/${tiketAId}`)
      .set('Authorization', `Bearer ${userB.token}`)
      .expect(404);

    await request(server())
      .get(`${endpoint}/${tiketBId}`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(404);

    await request(server())
      .get(`${endpoint}/${tiketBesarId}`)
      .set('Authorization', `Bearer ${userB.token}`)
      .expect(404);
  });

  // ==========================================
  // TEST 11: UUID INVALID DAN NOT FOUND
  // ==========================================

  it('mengembalikan 400 dan 404 untuk ID tidak valid', async () => {
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
  // TEST 12: READ TIDAK MENGUBAH DATABASE
  // ==========================================

  it('membaca tiket tanpa mengubah data atau counter', async () => {
    const sebelum = await db().tiketAntrean.findUnique({
      where: {
        id: tiketAId,
      },
    });

    await request(server())
      .get(`${endpoint}/${tiketAId}`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    await request(server())
      .get(`${endpoint}/saya`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(200);

    const sesudah = await db().tiketAntrean.findUnique({
      where: {
        id: tiketAId,
      },
    });

    expect(sesudah).toEqual(sebelum);

    const counter = await db().urutanAntreanHarian.findUnique({
      where: {
        layananId_tanggal: {
          layananId,
          tanggal: tanggalDatabase(tanggalUtama),
        },
      },
    });

    expect(counter?.nomorTerakhir).toBe(2);

    const jumlah = await db().tiketAntrean.count({
      where: {
        layananId,
      },
    });

    expect(jumlah).toBe(3);
  });
});
