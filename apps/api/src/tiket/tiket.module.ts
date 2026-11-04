import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { ReservasiModule } from '../reservasi/reservasi.module';

import { TiketController } from './tiket.controller';
import { TiketService } from './tiket.service';

@Module({
  imports: [AuthModule, PrismaModule, ReservasiModule],
  controllers: [TiketController],
  providers: [TiketService],
  exports: [TiketService],
})
export class TiketModule {}
