import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PeranPengguna, Prisma } from '../generated/prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import { CreateJadwalLayananDto } from './dto/create-jadwal-layanan.dto';
import { UpdateJadwalLayananDto } from './dto/update-jadwal-layanan.dto';

const pilihanLayanan = {
  id: true,
  kode: true,
  nama: true,
  aktif: true,
} as const;

@Injectable()
export class JadwalLayananService {
  constructor(private readonly prisma: PrismaService) {}

  // ==========================================
  // CREATE JADWAL
  // ==========================================

  async create(dto: CreateJadwalLayananDto) {
    this.validateJam(dto.jamBuka, dto.jamTutup);

    await this.ensureActiveService(dto.layananId);

    try {
      return await this.prisma.jadwalLayanan.create({
        data: {
          hari: dto.hari,
          jamBuka: this.toDbTime(dto.jamBuka),
          jamTutup: this.toDbTime(dto.jamTutup),
          kapasitasHarian: dto.kapasitasHarian,
          aktif: true,
          layanan: {
            connect: {
              id: dto.layananId,
            },
          },
        },
        include: {
          layanan: {
            select: pilihanLayanan,
          },
        },
      });
    } catch (error: unknown) {
      this.handleDatabaseError(error);
    }
  }

  // ==========================================
  // READ ALL
  // ==========================================

  findAll(peran: PeranPengguna) {
    const adalahAdmin = peran === PeranPengguna.ADMIN;

    const where: Prisma.JadwalLayananWhereInput = adalahAdmin
      ? {}
      : {
          aktif: true,
          layanan: {
            is: {
              aktif: true,
            },
          },
        };

    return this.prisma.jadwalLayanan.findMany({
      where,
      include: {
        layanan: {
          select: pilihanLayanan,
        },
      },
      orderBy: [{ layananId: 'asc' }, { hari: 'asc' }],
    });
  }

  // ==========================================
  // READ ONE
  // ==========================================

  async findOne(id: string, peran: PeranPengguna) {
    const adalahAdmin = peran === PeranPengguna.ADMIN;

    const where: Prisma.JadwalLayananWhereInput = {
      id,
      ...(adalahAdmin
        ? {}
        : {
            aktif: true,
            layanan: {
              is: {
                aktif: true,
              },
            },
          }),
    };

    const jadwal = await this.prisma.jadwalLayanan.findFirst({
      where,
      include: {
        layanan: {
          select: pilihanLayanan,
        },
      },
    });

    if (!jadwal) {
      throw new NotFoundException('Jadwal layanan tidak ditemukan');
    }

    return jadwal;
  }

  // ==========================================
  // UPDATE JADWAL
  // ==========================================

  async update(id: string, dto: UpdateJadwalLayananDto) {
    const existing = await this.prisma.jadwalLayanan.findUnique({
      where: { id },
      select: {
        id: true,
        layananId: true,
        jamBuka: true,
        jamTutup: true,
      },
    });

    if (!existing) {
      throw new NotFoundException('Jadwal layanan tidak ditemukan');
    }

    // Gunakan nilai existing untuk field jam
    // yang tidak dikirim pada PATCH.
    const jamBuka = dto.jamBuka ?? this.formatDbTime(existing.jamBuka);

    const jamTutup = dto.jamTutup ?? this.formatDbTime(existing.jamTutup);

    this.validateJam(jamBuka, jamTutup);

    // Cek layanan jika jadwal dipindahkan
    // atau diaktifkan kembali.
    if (dto.layananId !== undefined || dto.aktif === true) {
      await this.ensureActiveService(dto.layananId ?? existing.layananId);
    }

    try {
      return await this.prisma.jadwalLayanan.update({
        where: { id },
        data: {
          hari: dto.hari,
          jamBuka:
            dto.jamBuka !== undefined ? this.toDbTime(dto.jamBuka) : undefined,
          jamTutup:
            dto.jamTutup !== undefined
              ? this.toDbTime(dto.jamTutup)
              : undefined,
          kapasitasHarian: dto.kapasitasHarian,
          aktif: dto.aktif,
          layanan:
            dto.layananId !== undefined
              ? {
                  connect: {
                    id: dto.layananId,
                  },
                }
              : undefined,
        },
        include: {
          layanan: {
            select: pilihanLayanan,
          },
        },
      });
    } catch (error: unknown) {
      this.handleDatabaseError(error);
    }
  }

  // ==========================================
  // SOFT DELETE
  // ==========================================

  async remove(id: string) {
    try {
      return await this.prisma.jadwalLayanan.update({
        where: { id },
        data: {
          aktif: false,
        },
        include: {
          layanan: {
            select: pilihanLayanan,
          },
        },
      });
    } catch (error: unknown) {
      this.handleDatabaseError(error);
    }
  }

  // ==========================================
  // VALIDASI LAYANAN
  // ==========================================

  private async ensureActiveService(layananId: string): Promise<void> {
    const layanan = await this.prisma.layanan.findUnique({
      where: {
        id: layananId,
      },
      select: {
        id: true,
        aktif: true,
      },
    });

    if (!layanan) {
      throw new NotFoundException('Layanan tidak ditemukan');
    }

    if (!layanan.aktif) {
      throw new BadRequestException(
        'Jadwal hanya dapat ditautkan ke layanan aktif',
      );
    }
  }

  // ==========================================
  // VALIDASI JAM
  // ==========================================

  private validateJam(jamBuka: string, jamTutup: string): void {
    const polaJam = /^([01]\d|2[0-3]):[0-5]\d$/;

    if (!polaJam.test(jamBuka) || !polaJam.test(jamTutup)) {
      throw new BadRequestException('Jam harus menggunakan format HH:mm');
    }

    const bukaMenit = this.toMinutes(jamBuka);
    const tutupMenit = this.toMinutes(jamTutup);

    if (tutupMenit <= bukaMenit) {
      throw new BadRequestException(
        'Jam tutup harus lebih akhir daripada jam buka',
      );
    }
  }

  private toMinutes(jam: string): number {
    const [hours, minutes] = jam.split(':').map(Number);

    return hours * 60 + minutes;
  }

  // ==========================================
  // KONVERSI POSTGRESQL TIME(0)
  // ==========================================

  private toDbTime(jam: string): Date {
    // Tanggal 1970-01-01 hanya dipakai
    // sebagai representasi teknis Prisma.
    // PostgreSQL menyimpan bagian waktunya.
    return new Date(`1970-01-01T${jam}:00.000Z`);
  }

  private formatDbTime(value: Date): string {
    // Membaca jam UTC tanpa menggeser
    // jam operasional berdasarkan timezone server.
    return value.toISOString().slice(11, 16);
  }

  // ==========================================
  // DATABASE ERROR HANDLER
  // ==========================================

  private handleDatabaseError(error: unknown): never {
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === 'P2002') {
        throw new ConflictException(
          'Jadwal untuk hari tersebut sudah tersedia pada layanan ini',
        );
      }

      if (error.code === 'P2025') {
        throw new NotFoundException('Jadwal layanan tidak ditemukan');
      }

      if (error.code === 'P2003') {
        throw new BadRequestException('Relasi layanan tidak valid');
      }
    }

    throw error;
  }
}
