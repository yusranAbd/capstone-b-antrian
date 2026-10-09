import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

import { JadwalLayananController } from './jadwal-layanan.controller';
import { JadwalLayananService } from './jadwal-layanan.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [JadwalLayananController],
  providers: [JadwalLayananService],
  exports: [JadwalLayananService],
})
export class JadwalLayananModule {}
