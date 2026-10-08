import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

import { LayananController } from './layanan.controller';
import { LayananService } from './layanan.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [LayananController],
  providers: [LayananService],
  exports: [LayananService],
})
export class LayananModule {}
