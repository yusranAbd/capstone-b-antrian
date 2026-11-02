import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

import { LayananController } from './layanan.controller';
import { LayananService } from './layanan.service';
import { LayananReadinessService } from './layanan-readiness.service';
import { PatientQueueSummaryService } from './patient-queue-summary.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [LayananController],
  providers: [
    LayananService,
    PatientQueueSummaryService,
    LayananReadinessService,
  ],
  exports: [LayananService],
})
export class LayananModule {}
