import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

import { ReservasiController } from './reservasi.controller';
import { ReservasiService } from './reservasi.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [ReservasiController],
  providers: [ReservasiService],
  exports: [ReservasiService],
})
export class ReservasiModule {}
