import { createHash, randomBytes, randomUUID } from 'node:crypto';

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
// TIPE DATA
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

interface QrResponse {
  tiketId: string;
  qrPayload: string;
  berlakuHingga: string;
  masaBerlakuDetik: number;
  status: StatusTiket;
}

interface CheckInResponse {
  tiketId: string;
  layananId: string;
  nomorAntrean: string;
  status: StatusTiket;
  checkInPada: string;
  loketId: string;
  petugasId: string;
}

// ==========================================
// HELPER TANGGAL PELAYANAN
// ==========================================

function tanggalPelayananLokal(): string {
  const zonaWaktu = process.env.SERVICE_TIME_ZONE ?? 'Asia/Jakarta';

  const bagian = new Intl.DateTimeFormat('en-GB', {
    timeZone: zonaWaktu,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());

  const ambil = (jenis: string) =>
    bagian.find((item) => item.type === jenis)?.value ?? '';

  return [ambil('year'), ambil('month'), ambil('day')].join('-');
}

function tanggalDb(nilai: string): Date {
  return new Date(`${nilai}T00:00:00.000Z`);
}

function geserTanggal(tanggal: Date, jumlahHari: number): Date {
  return new Date(tanggal.getTime() + jumlahHari * 24 * 60 * 60 * 1000);
}

// ==========================================
// E2E QR CHECK-IN
// ==========================================

describe('QR Check-In API (e2e)', () => {
  let app: INestApplication | undefined;
  let prisma: PrismaService | undefined;

  let admin!: AkunUji;
  let userA!: AkunUji;
  let userB!: AkunUji;
  let petugasA!: AkunUji;
  let petugasB!: AkunUji;

  let layananId = '';
  let loketId = '';
  let tiketId = '';
  let nomorUrut = 0;

  let tanggalHariIni = '';
  let hariIniDb: Date;

  const penggunaIds: string[] = [];

  const unik = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();

  const kataSandi = 'RahasiaQrE2E123!';

  const semuaHari: HariLayanan[] = [
    HariLayanan.MINGGU,
    HariLayanan.SENIN,
    HariLayanan.SELASA,
    HariLayanan.RABU,
    HariLayanan.KAMIS,
    HariLayanan.JUMAT,
    HariLayanan.SABTU,
  ];

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

  // ========================================
  // HELPER AKUN
  // ========================================

  async function buatAkun(
    nama: string,
    peran: PeranPengguna,
  ): Promise<AkunUji> {
    const email = `qr-${randomUUID()}@test.local`;

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
        namaPerangkat: 'Jest E2E QR',
      })
      .expect(200);

    const hasilLogin = login.body as LoginResponse;

    expect(hasilLogin.user.peran).toBe(peran);

    return {
      id: hasilLogin.user.id,
      token: hasilLogin.accessToken,
    };
  }

  // ========================================
  // HELPER PENERBITAN DAN CHECK-IN
  // ========================================

  async function terbitkanQr(): Promise<QrResponse> {
    const response = await request(server())
      .post(`/api/v1/tiket/${tiketId}/qr`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(201);

    return response.body as QrResponse;
  }

  function pindaiQr(
    qrPayload: string,
    tokenPetugas: string = petugasA.token,
    idLoket: string = loketId,
  ) {
    return request(server())
      .post('/api/v1/check-in')
      .set('Authorization', `Bearer ${tokenPetugas}`)
      .send({
        qrPayload,
        loketId: idLoket,
      });
  }

  // ========================================
  // SETUP TEST DATABASE
  // ========================================

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
        'E2E hanya boleh memakai ' +
          'capstone_antrean_test lokal pada port 5433',
      );
    }

    tanggalHariIni = tanggalPelayananLokal();
    hariIniDb = tanggalDb(tanggalHariIni);

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

    admin = await buatAkun('Admin QR E2E', PeranPengguna.ADMIN);

    userA = await buatAkun('Pengguna QR A', PeranPengguna.USER);

    userB = await buatAkun('Pengguna QR B', PeranPengguna.USER);

    petugasA = await buatAkun('Petugas QR A', PeranPengguna.PETUGAS);

    petugasB = await buatAkun('Petugas QR B', PeranPengguna.PETUGAS);

    // Layanan khusus QR E2E.
    const layanan = await db().layanan.create({
      data: {
        kode: `QR${unik}`,
        nama: 'Layanan Pengujian QR',
        deskripsi: 'Khusus E2E QR Check-In',
        prefixAntrean: 'Q',
        durasiDasarMenit: 10,
        aktif: true,
      },
    });

    layananId = layanan.id;

    // Jadwal test mencakup seluruh hari.
    await db().jadwalLayanan.createMany({
      data: semuaHari.map((hari) => ({
        layananId,
        hari,
        jamBuka: new Date('1970-01-01T00:00:00.000Z'),
        jamTutup: new Date('1970-01-01T23:59:59.000Z'),
        kapasitasHarian: 1000,
        aktif: true,
      })),
    });

    // Loket aktif untuk layanan ini.
    const loket = await db().loket.create({
      data: {
        layananId,
        kode: `L${unik}`,
        nama: 'Loket QR E2E',
        lokasi: 'Ruang Testing',
        aktif: true,
      },
    });

    loketId = loket.id;

    // Dua petugas sama-sama berwenang
    // pada loket pengujian.
    const tanggalMulai = geserTanggal(hariIniDb, -1);

    const tanggalSelesai = geserTanggal(hariIniDb, 1);

    await db().penugasanPetugas.createMany({
      data: [
        {
          petugasId: petugasA.id,
          loketId,
          tanggalMulai,
          tanggalSelesai,
          aktif: true,
        },
        {
          petugasId: petugasB.id,
          loketId,
          tanggalMulai,
          tanggalSelesai,
          aktif: true,
        },
      ],
    });
  }, 120000);

  // ========================================
  // SATU TIKET SEGAR PER TEST
  // ========================================

  beforeEach(async () => {
    const counter = await db().urutanAntreanHarian.upsert({
      where: {
        layananId_tanggal: {
          layananId,
          tanggal: hariIniDb,
        },
      },
      create: {
        layananId,
        tanggal: hariIniDb,
        nomorTerakhir: 1,
      },
      update: {
        nomorTerakhir: {
          increment: 1,
        },
      },
    });

    nomorUrut = counter.nomorTerakhir;

    const tiket = await db().tiketAntrean.create({
      data: {
        penggunaId: userA.id,
        layananId,
        tanggalAntrean: hariIniDb,
        nomorUrut,
        kodeTiket: `TK${randomBytes(12).toString('hex').toUpperCase()}`,
        status: StatusTiket.DIPESAN,
      },
    });

    tiketId = tiket.id;
  }, 30000);

  afterEach(async () => {
    if (!prisma || !tiketId) {
      return;
    }

    await db().peristiwaAntrean.deleteMany({
      where: {
        tiketAntreanId: tiketId,
      },
    });

    await db().tiketAntrean.deleteMany({
      where: {
        id: tiketId,
      },
    });

    tiketId = '';
  }, 30000);

  // ========================================
  // CLEANUP
  // ========================================

  afterAll(async () => {
    try {
      if (prisma) {
        if (layananId) {
          const tiketTersisa = await prisma.tiketAntrean.findMany({
            where: {
              layananId,
            },
            select: {
              id: true,
            },
          });

          const idTiket = tiketTersisa.map((item) => item.id);

          if (idTiket.length > 0) {
            await prisma.peristiwaAntrean.deleteMany({
              where: {
                tiketAntreanId: {
                  in: idTiket,
                },
              },
            });
          }

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

          await prisma.penugasanPetugas.deleteMany({
            where: {
              loketId,
            },
          });

          await prisma.jadwalLayanan.deleteMany({
            where: {
              layananId,
            },
          });

          await prisma.loket.deleteMany({
            where: {
              layananId,
            },
          });

          await prisma.layanan.deleteMany({
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

  // ========================================
  // 1. JWT
  // ========================================

  it('menolak penerbitan QR dan check-in tanpa JWT', async () => {
    await request(server()).post(`/api/v1/tiket/${tiketId}/qr`).expect(401);

    await request(server())
      .post('/api/v1/check-in')
      .send({
        qrPayload: `SQ1.${'A'.repeat(43)}`,
        loketId,
      })
      .expect(401);
  });

  // ========================================
  // 2. ROLE ACCESS
  // ========================================

  it('membatasi penerbitan QR dan scan berdasarkan role', async () => {
    await request(server())
      .post(`/api/v1/tiket/${tiketId}/qr`)
      .set('Authorization', `Bearer ${admin.token}`)
      .expect(403);

    await request(server())
      .post(`/api/v1/tiket/${tiketId}/qr`)
      .set('Authorization', `Bearer ${petugasA.token}`)
      .expect(403);

    await pindaiQr(`SQ1.${'A'.repeat(43)}`, userA.token).expect(403);

    await pindaiQr(`SQ1.${'A'.repeat(43)}`, admin.token).expect(403);
  });

  // ========================================
  // 3. PENERBITAN QR AMAN
  // ========================================

  it('menerbitkan token QR dengan hash dan expiry', async () => {
    const qr = await terbitkanQr();

    expect(qr.tiketId).toBe(tiketId);
    expect(qr.qrPayload).toMatch(/^SQ1\.[A-Za-z0-9_-]{43}$/);

    expect(qr.masaBerlakuDetik).toBe(600);
    expect(qr.status).toBe(StatusTiket.DIPESAN);

    const tiket = await db().tiketAntrean.findUnique({
      where: {
        id: tiketId,
      },
    });

    const hash = createHash('sha256')
      .update(qr.qrPayload, 'utf8')
      .digest('hex');

    expect(tiket?.tokenQrHash).toBe(hash);

    expect(tiket?.qrKedaluwarsaPada).not.toBeNull();

    expect(new Date(qr.berlakuHingga).getTime()).toBeGreaterThan(Date.now());

    expect(qr).not.toHaveProperty('tokenQrHash');
  });

  // ========================================
  // 4. KEPEMILIKAN
  // ========================================

  it('menolak QR tiket yang bukan milik pengguna', async () => {
    await request(server())
      .post(`/api/v1/tiket/${tiketId}/qr`)
      .set('Authorization', `Bearer ${userB.token}`)
      .expect(404);

    await request(server())
      .post('/api/v1/tiket/bukan-uuid/qr')
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(400);
  });

  // ========================================
  // 5. VALIDASI TANGGAL PENERBITAN
  // ========================================

  it('menolak QR sebelum tanggal pelayanan', async () => {
    await db().tiketAntrean.update({
      where: {
        id: tiketId,
      },
      data: {
        tanggalAntrean: geserTanggal(hariIniDb, 2),
      },
    });

    await request(server())
      .post(`/api/v1/tiket/${tiketId}/qr`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(400);
  });

  // ========================================
  // 6. STATUS TIKET
  // ========================================

  it('menolak penerbitan QR untuk tiket yang sudah CHECK_IN', async () => {
    await db().tiketAntrean.update({
      where: {
        id: tiketId,
      },
      data: {
        status: StatusTiket.CHECK_IN,
      },
    });

    await request(server())
      .post(`/api/v1/tiket/${tiketId}/qr`)
      .set('Authorization', `Bearer ${userA.token}`)
      .expect(409);
  });

  // ========================================
  // 7. ROTASI QR
  // ========================================

  it('penerbitan QR baru membatalkan token sebelumnya', async () => {
    const pertama = await terbitkanQr();
    const kedua = await terbitkanQr();

    expect(pertama.qrPayload).not.toBe(kedua.qrPayload);

    await pindaiQr(pertama.qrPayload).expect(400);

    await pindaiQr(kedua.qrPayload).expect(200);
  });

  // ========================================
  // 8. TOKEN INVALID
  // ========================================

  it('menolak format QR dan token palsu', async () => {
    await pindaiQr('bukan-qr').expect(400);

    await pindaiQr(`SQ1.${'Z'.repeat(43)}`).expect(400);

    await pindaiQr(
      `SQ1.${'Z'.repeat(43)}`,
      petugasA.token,
      'bukan-uuid',
    ).expect(400);
  });

  // ========================================
  // 9. EXPIRED TOKEN
  // ========================================

  it('menolak QR yang sudah kedaluwarsa', async () => {
    const qr = await terbitkanQr();

    await db().tiketAntrean.update({
      where: {
        id: tiketId,
      },
      data: {
        qrKedaluwarsaPada: new Date(Date.now() - 60 * 1000),
      },
    });

    await pindaiQr(qr.qrPayload).expect(410);

    const tiket = await db().tiketAntrean.findUnique({
      where: {
        id: tiketId,
      },
    });

    expect(tiket?.status).toBe(StatusTiket.DIPESAN);
  });

  // ========================================
  // 10. PENUGASAN NONAKTIF
  // ========================================

  it('menolak scan dari petugas tanpa penugasan aktif', async () => {
    const qr = await terbitkanQr();

    const where = {
      petugasId: petugasA.id,
      loketId,
    };

    await db().penugasanPetugas.updateMany({
      where,
      data: {
        aktif: false,
      },
    });

    try {
      await pindaiQr(qr.qrPayload, petugasA.token).expect(403);
    } finally {
      await db().penugasanPetugas.updateMany({
        where,
        data: {
          aktif: true,
        },
      });
    }
  });

  // ========================================
  // 11. TANGGAL CHECK-IN SALAH
  // ========================================

  it('menolak check-in di luar tanggal tiket', async () => {
    const qr = await terbitkanQr();

    // Ubah hanya data tiket E2E.
    await db().tiketAntrean.update({
      where: {
        id: tiketId,
      },
      data: {
        tanggalAntrean: geserTanggal(hariIniDb, 1),
      },
    });

    await pindaiQr(qr.qrPayload).expect(400);
  });

  // ========================================
  // 12. CHECK-IN BERHASIL DAN ANTI-REPLAY
  // ========================================

  it('check-in berhasil, audit tercatat, dan QR tidak dapat dipakai ulang', async () => {
    const qr = await terbitkanQr();

    const sebelum = await db().tiketAntrean.findUniqueOrThrow({
      where: {
        id: tiketId,
      },
    });

    const response = await pindaiQr(qr.qrPayload).expect(200);

    const hasil = response.body as CheckInResponse;

    expect(hasil.tiketId).toBe(tiketId);
    expect(hasil.status).toBe(StatusTiket.CHECK_IN);

    expect(hasil.loketId).toBe(loketId);
    expect(hasil.petugasId).toBe(petugasA.id);

    expect(hasil.nomorAntrean).toBe(`Q-${String(nomorUrut).padStart(3, '0')}`);

    const sesudah = await db().tiketAntrean.findUniqueOrThrow({
      where: {
        id: tiketId,
      },
    });

    expect(sesudah.status).toBe(StatusTiket.CHECK_IN);

    expect(sesudah.checkInPada).not.toBeNull();
    expect(sesudah.tokenQrHash).toBeNull();
    expect(sesudah.qrKedaluwarsaPada).toBeNull();
    expect(sesudah.loketId).toBe(loketId);
    expect(sesudah.versi).toBe(sebelum.versi + 1);

    const audit = await db().peristiwaAntrean.findMany({
      where: {
        tiketAntreanId: tiketId,
        tipe: 'CHECK_IN',
      },
    });

    expect(audit).toHaveLength(1);

    expect(audit[0]).toMatchObject({
      aktorId: petugasA.id,
      statusSebelum: StatusTiket.DIPESAN,
      statusSesudah: StatusTiket.CHECK_IN,
    });

    // Scan ulang harus ditolak.
    await pindaiQr(qr.qrPayload).expect(400);
  }, 30000);

  // ========================================
  // 13. RACE CONDITION
  // ========================================

  it('dua petugas tidak dapat check-in tiket yang sama secara bersamaan', async () => {
    const qr = await terbitkanQr();

    const sebelum = await db().tiketAntrean.findUniqueOrThrow({
      where: {
        id: tiketId,
      },
    });

    const [hasilA, hasilB] = await Promise.all([
      pindaiQr(qr.qrPayload, petugasA.token),
      pindaiQr(qr.qrPayload, petugasB.token),
    ]);

    const status = [hasilA.status, hasilB.status];

    // Tepat satu request berhasil.
    expect(status.filter((nilai) => nilai === 200)).toHaveLength(1);

    const penolakan = status.find((nilai) => nilai !== 200);

    expect([400, 409]).toContain(penolakan);

    const tiket = await db().tiketAntrean.findUniqueOrThrow({
      where: {
        id: tiketId,
      },
    });

    expect(tiket.status).toBe(StatusTiket.CHECK_IN);

    expect(tiket.versi).toBe(sebelum.versi + 1);

    expect(tiket.tokenQrHash).toBeNull();

    const jumlahAudit = await db().peristiwaAntrean.count({
      where: {
        tiketAntreanId: tiketId,
        tipe: 'CHECK_IN',
      },
    });

    expect(jumlahAudit).toBe(1);
  }, 30000);

  // ========================================
  // 14. CHECK-IN DI LUAR JAM PELAYANAN
  // ========================================

  it('menolak check-in di luar jam pelayanan tanpa mengubah tiket', async () => {
    // 1. Terbitkan QR valid untuk tiket test.
    const qr = await terbitkanQr();

    const sebelum = await db().tiketAntrean.findUniqueOrThrow({
      where: {
        id: tiketId,
      },
    });

    // 2. Temukan jadwal hari pelayanan.
    const hari = semuaHari[hariIniDb.getUTCDay()];

    const whereJadwal = {
      layananId_hari: {
        layananId,
        hari,
      },
    };

    const jadwalAsli = await db().jadwalLayanan.findUniqueOrThrow({
      where: whereJadwal,
    });

    // 3. Tentukan rentang waktu yang pasti
    // berada di luar jam saat test berjalan.
    const zonaWaktu = process.env.SERVICE_TIME_ZONE ?? 'Asia/Jakarta';

    const bagianJam = new Intl.DateTimeFormat('en-GB', {
      timeZone: zonaWaktu,
      hour: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(new Date());

    const jamSekarang = Number(
      bagianJam.find((bagian) => bagian.type === 'hour')?.value ?? '0',
    );

    // Pagi: jadwal 15.00-16.00.
    // Siang/malam: jadwal 03.00-04.00.
    const jamBuka = jamSekarang < 12 ? '15:00:00' : '03:00:00';

    const jamTutup = jamSekarang < 12 ? '16:00:00' : '04:00:00';

    await db().jadwalLayanan.update({
      where: whereJadwal,
      data: {
        jamBuka: new Date(`1970-01-01T${jamBuka}.000Z`),
        jamTutup: new Date(`1970-01-01T${jamTutup}.000Z`),
      },
    });

    try {
      // 4. Petugas mencoba check-in.
      const response = await pindaiQr(qr.qrPayload).expect(400);

      expect(response.body).toMatchObject({
        message: 'Check-in berada di luar jam pelayanan',
      });

      // 5. Pastikan tiket tetap DIPESAN.
      const sesudah = await db().tiketAntrean.findUniqueOrThrow({
        where: {
          id: tiketId,
        },
      });

      expect(sesudah.status).toBe(StatusTiket.DIPESAN);

      expect(sesudah.checkInPada).toBeNull();

      // QR tidak boleh dikonsumsi.
      expect(sesudah.tokenQrHash).toBe(sebelum.tokenQrHash);

      // Versi tidak berubah.
      expect(sesudah.versi).toBe(sebelum.versi);

      // Tidak boleh ada audit CHECK_IN.
      const jumlahAudit = await db().peristiwaAntrean.count({
        where: {
          tiketAntreanId: tiketId,
          tipe: 'CHECK_IN',
        },
      });

      expect(jumlahAudit).toBe(0);
    } finally {
      // 6. WAJIB kembalikan jadwal.
      await db().jadwalLayanan.update({
        where: whereJadwal,
        data: {
          jamBuka: jadwalAsli.jamBuka,
          jamTutup: jadwalAsli.jamTutup,
        },
      });
    }
  }, 30000);

  // ========================================
  // 15. ROLLBACK KETIKA AUDIT GAGAL
  // ========================================

  it('melakukan rollback jika audit CHECK_IN gagal disimpan', async () => {
    const qr = await terbitkanQr();

    // 1. Simpan kondisi tiket sebelum scan.
    const sebelum = await db().tiketAntrean.findUniqueOrThrow({
      where: {
        id: tiketId,
      },
    });

    expect(sebelum.status).toBe(StatusTiket.DIPESAN);

    expect(sebelum.tokenQrHash).not.toBeNull();

    // 2. Pengamanan ID untuk statement DDL.
    // ID berasal dari database testing.
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        tiketId,
      )
    ) {
      throw new Error('UUID tiket pengujian tidak valid');
    }

    // 3. Validasi ekstra untuk memastikan
    // DDL tidak menyentuh database development.
    const databaseUrl = process.env.DATABASE_URL;

    if (!databaseUrl) {
      throw new Error('DATABASE_URL test tidak ditemukan');
    }

    const url = new URL(databaseUrl);

    if (
      url.pathname !== '/capstone_antrean_test' ||
      !['127.0.0.1', 'localhost'].includes(url.hostname) ||
      url.port !== '5433'
    ) {
      throw new Error(
        'Rollback E2E hanya boleh menggunakan database testing lokal',
      );
    }

    // 4. Nama constraint unik khusus test ini.
    const namaConstraint = `e2e_qr_rollback_${randomUUID()
      .replace(/-/g, '')
      .slice(0, 12)}`;

    let constraintTerpasang = false;

    try {
      // 5. Tambahkan constraint sementara.
      // Hanya audit untuk tiket ini yang
      // sengaja dibuat gagal.
      await db().$executeRawUnsafe(
        `ALTER TABLE "public"."peristiwa_antrean"
         ADD CONSTRAINT "${namaConstraint}"
         CHECK (
           "tiket_antrean_id" <>
           '${tiketId}'::uuid
         )`,
      );

      constraintTerpasang = true;

      // 6. Lakukan scan QR sebenarnya.
      // Audit gagal setelah update tiket.
      // Tanpa transaction rollback, tiket
      // akan tertinggal di status CHECK_IN.
      const response = await pindaiQr(qr.qrPayload);

      // Kegagalan database yang disengaja
      // menghasilkan internal server error.
      expect(response.status).toBe(500);
    } finally {
      // 7. SELALU hapus constraint test.
      if (constraintTerpasang) {
        await db().$executeRawUnsafe(
          `ALTER TABLE "public"."peristiwa_antrean"
           DROP CONSTRAINT IF EXISTS
           "${namaConstraint}"`,
        );
      }
    }

    // 8. Periksa keadaan database
    // setelah transaksi gagal.
    const sesudah = await db().tiketAntrean.findUniqueOrThrow({
      where: {
        id: tiketId,
      },
    });

    // Status tidak boleh berubah.
    expect(sesudah.status).toBe(StatusTiket.DIPESAN);

    expect(sesudah.checkInPada).toBeNull();
    expect(sesudah.loketId).toBeNull();

    // Hash dan expiry tetap tersimpan.
    expect(sesudah.tokenQrHash).toBe(sebelum.tokenQrHash);

    expect(sesudah.qrKedaluwarsaPada).toEqual(sebelum.qrKedaluwarsaPada);

    // Versi tetap sama.
    expect(sesudah.versi).toBe(sebelum.versi);

    // Tidak ada catatan audit parsial.
    const jumlahAudit = await db().peristiwaAntrean.count({
      where: {
        tiketAntreanId: tiketId,
        tipe: 'CHECK_IN',
      },
    });

    expect(jumlahAudit).toBe(0);
  }, 30000);
});
