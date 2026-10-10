import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

import { CheckInController } from './check-in.controller';
import { CheckInService } from './check-in.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [CheckInController],
  providers: [CheckInService],
  exports: [CheckInService],
})
export class CheckInModule {}
