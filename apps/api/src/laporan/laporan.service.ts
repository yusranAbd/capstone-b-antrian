import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { ReportQuery } from './laporan.module';
import { period } from './period-query';

export interface OperationalRow {
  agregat: number;
  tanggal: string | null;
  layananId: string | null;
  kodeLayanan: string | null;
  namaLayanan: string | null;
  totalTiket: number;
  pasienUnik: number;
  dipesan: number;
  checkIn: number;
  menunggu: number;
  dipanggil: number;
  dilayani: number;
  selesai: number;
  dibatalkan: number;
  dilewati: number;
  sampelTunggu: number;
  rataTungguDetik: number | null;
  sampelPelayanan: number;
  rataPelayananDetik: number | null;
}
@Injectable()
export class LaporanService {
  constructor(private readonly prisma: PrismaService) {}
  async read(query: ReportQuery) {
    const dates = period(query);
    const data = await this.prisma.$queryRaw<OperationalRow[]>(Prisma.sql`
      SELECT GROUPING(t.tanggal_antrean)::int AS agregat,
        to_char(t.tanggal_antrean,'YYYY-MM-DD') AS tanggal,
        l.id AS "layananId", l.kode AS "kodeLayanan", l.nama AS "namaLayanan",
        COUNT(*)::int AS "totalTiket", COUNT(DISTINCT t.pengguna_id)::int AS "pasienUnik",
        COUNT(*) FILTER (WHERE t.status='DIPESAN')::int AS dipesan,
        COUNT(*) FILTER (WHERE t.status='CHECK_IN')::int AS "checkIn",
        COUNT(*) FILTER (WHERE t.status='MENUNGGU')::int AS menunggu,
        COUNT(*) FILTER (WHERE t.status='DIPANGGIL')::int AS dipanggil,
        COUNT(*) FILTER (WHERE t.status='DILAYANI')::int AS dilayani,
        COUNT(*) FILTER (WHERE t.status='SELESAI')::int AS selesai,
        COUNT(*) FILTER (WHERE t.status='DIBATALKAN')::int AS dibatalkan,
        COUNT(*) FILTER (WHERE t.status='DILEWATI')::int AS dilewati,
        COUNT(*) FILTER (WHERE t.pelayanan_dimulai_pada >= t.check_in_pada)::int AS "sampelTunggu",
        AVG(EXTRACT(EPOCH FROM (t.pelayanan_dimulai_pada-t.check_in_pada)))
          FILTER (WHERE t.pelayanan_dimulai_pada >= t.check_in_pada)::float8 AS "rataTungguDetik",
        COUNT(*) FILTER (WHERE t.pelayanan_selesai_pada >= t.pelayanan_dimulai_pada)::int AS "sampelPelayanan",
        AVG(EXTRACT(EPOCH FROM (t.pelayanan_selesai_pada-t.pelayanan_dimulai_pada)))
          FILTER (WHERE t.pelayanan_selesai_pada >= t.pelayanan_dimulai_pada)::float8 AS "rataPelayananDetik"
      FROM tiket_antrean t JOIN layanan l ON l.id=t.layanan_id
      WHERE t.tanggal_antrean >= ${dates.mulai}::date AND t.tanggal_antrean <= ${dates.selesai}::date
        ${query.layananId ? Prisma.sql`AND t.layanan_id=${query.layananId}::uuid` : Prisma.empty}
      GROUP BY GROUPING SETS ((t.tanggal_antrean,l.id,l.kode,l.nama), ())
      ORDER BY agregat DESC, tanggal ASC, "namaLayanan" ASC, "layananId" ASC
      LIMIT 5002
    `);
    if (data.length > 5001)
      throw new BadRequestException(
        'Laporan melebihi 5000 baris. Persempit periode atau pilih satu layanan',
      );
    const metrics = (row: OperationalRow) => {
      const {
        agregat,
        tanggal,
        layananId,
        kodeLayanan,
        namaLayanan,
        ...values
      } = row;
      return values;
    };
    return {
      periode: {
        mulai: query.mulai,
        selesai: query.selesai,
        layananId: query.layananId ?? null,
        zonaWaktu: process.env.SERVICE_TIME_ZONE ?? 'Asia/Jakarta',
      },
      diperolehPada: new Date().toISOString(),
      ringkasan: metrics(data.find((row) => row.agregat === 1)!),
      baris: data
        .filter((row) => row.agregat === 0)
        .map((row) => {
          const { agregat, ...values } = row;
          return values;
        }),
    };
  }
}
