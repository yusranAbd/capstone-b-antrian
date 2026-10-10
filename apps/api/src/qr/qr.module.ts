import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

import { QrController } from './qr.controller';
import { QrService } from './qr.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [QrController],
  providers: [QrService],
  exports: [QrService],
})
export class QrModule {}
