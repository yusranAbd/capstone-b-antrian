import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';

import { AuthModule } from './auth/auth.module';
import { validateEnvironment } from './config/env.validation';
import { HealthModule } from './health/health.module';
import { LayananModule } from './layanan/layanan.module';
import { LoketModule } from './loket/loket.module';
import { JadwalLayananModule } from './jadwal-layanan/jadwal-layanan.module';
import { PenugasanPetugasModule } from './penugasan-petugas/penugasan-petugas.module';
import { ReservasiModule } from './reservasi/reservasi.module';
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['../../.env', '.env'],
      validate: validateEnvironment,
    }),

    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: 100,
      },
    ]),

    HealthModule,
    AuthModule,
    LayananModule,
    LoketModule,
    JadwalLayananModule,
    PenugasanPetugasModule,
    ReservasiModule,
  ],
})
export class AppModule {}
