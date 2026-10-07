import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async check() {
    await this.prisma.isHealthy();

    return {
      status: 'ok',
      service: 'capstone-antrean-api',
      database: 'connected',
      timestamp: new Date().toISOString(),
    };
  }
}
