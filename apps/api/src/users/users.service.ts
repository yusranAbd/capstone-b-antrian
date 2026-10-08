import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  findByEmail(email: string) {
    return this.prisma.pengguna.findUnique({
      where: {
        email,
      },
    });
  }

  findById(id: string) {
    return this.prisma.pengguna.findUnique({
      where: {
        id,
      },
    });
  }

  create(data: { nama: string; email: string; kataSandiHash: string }) {
    return this.prisma.pengguna.create({
      data: {
        nama: data.nama,
        email: data.email,
        kataSandiHash: data.kataSandiHash,
        peran: 'USER',
      },
    });
  }
}
