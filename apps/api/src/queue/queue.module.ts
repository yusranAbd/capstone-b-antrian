import {
  DisplayDeviceController,
  DisplayPairingController,
} from '../display/display-device.controller';
import { DisplayDeviceService } from '../display/display-device.service';
import { Module } from '@nestjs/common';

import { DisplayController } from '../display/display.controller';
import { DisplayService } from '../display/display.service';
import { PrismaModule } from '../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { QueueController } from './queue.controller';
import { QueueService } from './queue.service';
import { QueueResolutionService } from './queue-resolution.service';

@Module({
  imports: [PrismaModule, RealtimeModule],
  controllers: [
    QueueController,
    DisplayController,
    DisplayDeviceController,
    DisplayPairingController,
  ],
  providers: [
    QueueService,
    QueueResolutionService,
    DisplayService,
    DisplayDeviceService,
  ],
  exports: [QueueService],
})
export class QueueModule {}
