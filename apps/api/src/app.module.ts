import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';

import { AuthModule } from './auth/auth.module';
import { validateEnvironment } from './config/env.validation';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['../../.env', '.env'],
      validate: validateEnvironment,
    }),

    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: 100,
      },
    ]),

    HealthModule,
    AuthModule,
  ],
})
export class AppModule {}
