import { config } from 'dotenv';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import { HariLayanan, PrismaClient } from '../src/generated/prisma/client';

config({
  path: '../../.env',
  override: true,
});

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL tidak tersedia');
}

const pool = new Pool({
  connectionString,
});

const adapter = new PrismaPg(pool);

const prisma = new PrismaClient({
  adapter,
});

function waktu(jam: string): Date {
  return new Date(`1970-01-01T${jam}:00.000Z`);
}

async function seedLayanan() {
  console.log('Menambahkan master layanan...');

  const administrasi = await prisma.layanan.upsert({
    where: {
      kode: 'ADM',
    },
    update: {
      nama: 'Layanan Administrasi Umum',
      deskripsi: 'Pelayanan administrasi umum.',
      prefixAntrean: 'A',
      durasiDasarMenit: 15,
      aktif: true,
    },
    create: {
      kode: 'ADM',
      nama: 'Layanan Administrasi Umum',
      deskripsi: 'Pelayanan administrasi umum.',
      prefixAntrean: 'A',
      durasiDasarMenit: 15,
      aktif: true,
    },
  });

  const verifikasi = await prisma.layanan.upsert({
    where: {
      kode: 'VRF',
    },
    update: {
      nama: 'Verifikasi Dokumen',
      deskripsi: 'Pelayanan pemeriksaan dan verifikasi dokumen.',
      prefixAntrean: 'V',
      durasiDasarMenit: 10,
      aktif: true,
    },
    create: {
      kode: 'VRF',
      nama: 'Verifikasi Dokumen',
      deskripsi: 'Pelayanan pemeriksaan dan verifikasi dokumen.',
      prefixAntrean: 'V',
      durasiDasarMenit: 10,
      aktif: true,
    },
  });

  const informasi = await prisma.layanan.upsert({
    where: {
      kode: 'INF',
    },
    update: {
      nama: 'Informasi dan Pengaduan',
      deskripsi: 'Pelayanan informasi dan penerimaan pengaduan.',
      prefixAntrean: 'I',
      durasiDasarMenit: 10,
      aktif: true,
    },
    create: {
      kode: 'INF',
      nama: 'Informasi dan Pengaduan',
      deskripsi: 'Pelayanan informasi dan penerimaan pengaduan.',
      prefixAntrean: 'I',
      durasiDasarMenit: 10,
      aktif: true,
    },
  });

  return {
    administrasi,
    verifikasi,
    informasi,
  };
}

async function seedLoket(layanan: Awaited<ReturnType<typeof seedLayanan>>) {
  console.log('Menambahkan master loket...');

  const data = [
    {
      layananId: layanan.administrasi.id,
      kode: 'LKT-A1',
      nama: 'Loket Administrasi 1',
      lokasi: 'Ruang Pelayanan',
    },
    {
      layananId: layanan.verifikasi.id,
      kode: 'LKT-V1',
      nama: 'Loket Verifikasi 1',
      lokasi: 'Ruang Pelayanan',
    },
    {
      layananId: layanan.informasi.id,
      kode: 'LKT-I1',
      nama: 'Loket Informasi 1',
      lokasi: 'Ruang Pelayanan',
    },
  ];

  for (const item of data) {
    await prisma.loket.upsert({
      where: {
        layananId_kode: {
          layananId: item.layananId,
          kode: item.kode,
        },
      },
      update: {
        nama: item.nama,
        lokasi: item.lokasi,
        aktif: true,
      },
      create: {
        ...item,
        aktif: true,
      },
    });
  }
}

async function seedJadwal(layanan: Awaited<ReturnType<typeof seedLayanan>>) {
  console.log('Menambahkan jadwal layanan...');

  const layananIds = [
    layanan.administrasi.id,
    layanan.verifikasi.id,
    layanan.informasi.id,
  ];

  const hariKerja: HariLayanan[] = [
    HariLayanan.SENIN,
    HariLayanan.SELASA,
    HariLayanan.RABU,
    HariLayanan.KAMIS,
    HariLayanan.JUMAT,
  ];

  for (const layananId of layananIds) {
    for (const hari of hariKerja) {
      await prisma.jadwalLayanan.upsert({
        where: {
          layananId_hari: {
            layananId,
            hari,
          },
        },
        update: {
          jamBuka: waktu('08:00'),
          jamTutup: waktu('15:00'),
          kapasitasHarian: 100,
          aktif: true,
        },
        create: {
          layananId,
          hari,
          jamBuka: waktu('08:00'),
          jamTutup: waktu('15:00'),
          kapasitasHarian: 100,
          aktif: true,
        },
      });
    }
  }
}

async function main() {
  console.log('===================================');
  console.log('Seed Database Capstone Antrean');
  console.log('===================================');

  const layanan = await seedLayanan();

  await seedLoket(layanan);
  await seedJadwal(layanan);

  console.log('');
  console.log('Seed database berhasil.');
}

main()
  .then(async () => {
    await prisma.$disconnect();
    await pool.end();
  })
  .catch(async (error) => {
    console.error('Seed database gagal:');
    console.error(error);

    await prisma.$disconnect();
    await pool.end();

    process.exit(1);
  });
