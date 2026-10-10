import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { ReservasiModule } from '../reservasi/reservasi.module';

import { TiketController } from './tiket.controller';
import { TiketService } from './tiket.service';

@Module({
  imports: [AuthModule, ReservasiModule],
  controllers: [TiketController],
  providers: [TiketService],
  exports: [TiketService],
})
export class TiketModule {}
