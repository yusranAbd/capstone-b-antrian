import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

import { LoketController } from './loket.controller';
import { LoketService } from './loket.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [LoketController],
  providers: [LoketService],
  exports: [LoketService],
})
export class LoketModule {}
