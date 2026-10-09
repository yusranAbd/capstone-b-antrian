import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PeranPengguna, Prisma } from '../generated/prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { CreateLoketDto } from './dto/create-loket.dto';
import { UpdateLoketDto } from './dto/update-loket.dto';

@Injectable()
export class LoketService {
  constructor(private readonly prisma: PrismaService) {}

  // ==========================================
  // CREATE LOKET
  // ==========================================

  async create(dto: CreateLoketDto) {
    await this.ensureActiveService(dto.layananId);

    try {
      return await this.prisma.loket.create({
        data: {
          kode: dto.kode,
          nama: dto.nama.trim(),
          lokasi: dto.lokasi?.trim() || null,
          aktif: true,
          layanan: {
            connect: {
              id: dto.layananId,
            },
          },
        },
        include: {
          layanan: {
            select: {
              id: true,
              kode: true,
              nama: true,
              aktif: true,
            },
          },
        },
      });
    } catch (error: unknown) {
      this.handleDatabaseError(error);
    }
  }

  // ==========================================
  // READ ALL LOKET
  // ==========================================

  findAll(peran: PeranPengguna) {
    const adalahAdmin = peran === PeranPengguna.ADMIN;

    const where: Prisma.LoketWhereInput = adalahAdmin
      ? {}
      : {
          aktif: true,
          layanan: {
            is: {
              aktif: true,
            },
          },
        };

    return this.prisma.loket.findMany({
      where,
      include: {
        layanan: {
          select: {
            id: true,
            kode: true,
            nama: true,
            aktif: true,
          },
        },
      },
      orderBy: [
        {
          layananId: 'asc',
        },
        {
          kode: 'asc',
        },
      ],
    });
  }

  // ==========================================
  // READ ONE LOKET
  // ==========================================

  async findOne(id: string, peran: PeranPengguna) {
    const adalahAdmin = peran === PeranPengguna.ADMIN;

    const where: Prisma.LoketWhereInput = {
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

    const loket = await this.prisma.loket.findFirst({
      where,
      include: {
        layanan: {
          select: {
            id: true,
            kode: true,
            nama: true,
            aktif: true,
          },
        },
      },
    });

    if (!loket) {
      throw new NotFoundException('Loket tidak ditemukan');
    }

    return loket;
  }

  // ==========================================
  // UPDATE LOKET
  // ==========================================

  async update(id: string, dto: UpdateLoketDto) {
    const existing = await this.prisma.loket.findUnique({
      where: { id },
      select: {
        id: true,
        layananId: true,
      },
    });

    if (!existing) {
      throw new NotFoundException('Loket tidak ditemukan');
    }

    // Validasi layanan apabila loket dipindahkan
    // atau loket diaktifkan kembali.
    if (dto.layananId !== undefined || dto.aktif === true) {
      await this.ensureActiveService(dto.layananId ?? existing.layananId);
    }

    try {
      return await this.prisma.loket.update({
        where: { id },
        data: {
          kode: dto.kode,
          nama: dto.nama !== undefined ? dto.nama.trim() : undefined,
          lokasi:
            dto.lokasi === undefined ? undefined : dto.lokasi?.trim() || null,
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
            select: {
              id: true,
              kode: true,
              nama: true,
              aktif: true,
            },
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
      return await this.prisma.loket.update({
        where: { id },
        data: {
          aktif: false,
        },
        include: {
          layanan: {
            select: {
              id: true,
              kode: true,
              nama: true,
              aktif: true,
            },
          },
        },
      });
    } catch (error: unknown) {
      this.handleDatabaseError(error);
    }
  }

  // ==========================================
  // CEK LAYANAN AKTIF
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
        'Loket hanya dapat ditautkan ke layanan aktif',
      );
    }
  }

  // ==========================================
  // DATABASE ERROR HANDLER
  // ==========================================

  private handleDatabaseError(error: unknown): never {
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === 'P2002') {
        throw new ConflictException(
          'Kode loket sudah digunakan pada layanan tersebut',
        );
      }

      if (error.code === 'P2025') {
        throw new NotFoundException('Loket tidak ditemukan');
      }

      if (error.code === 'P2003') {
        throw new BadRequestException('Relasi layanan tidak valid');
      }
    }

    throw error;
  }
}
