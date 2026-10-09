import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

import { PenugasanPetugasController } from './penugasan-petugas.controller';
import { PenugasanPetugasService } from './penugasan-petugas.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [PenugasanPetugasController],
  providers: [PenugasanPetugasService],
  exports: [PenugasanPetugasService],
})
export class PenugasanPetugasModule {}
