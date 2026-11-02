import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';

import { Throttle, ThrottlerGuard } from '@nestjs/throttler';

import { AuthService } from './auth.service';
import type { AuthenticatedUser } from './auth.types';

import { CurrentUser } from './decorators/current-user.decorator';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { ProfileService } from './profile/profile.service';
import { authAuditContext } from './audit/auth-audit.service';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly profile: ProfileService,
  ) {}

  // =====================================
  // REGISTER
  // Maksimal 3 request per menit
  // =====================================

  @Post('register')
  @UseGuards(ThrottlerGuard)
  @Throttle({
    default: {
      limit: 3,
      ttl: 60_000,
    },
  })
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  // =====================================
  // LOGIN
  // Maksimal 5 request per menit
  // =====================================

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @Throttle({
    default: {
      limit: 5,
      ttl: 60_000,
    },
  })
  login(@Body() dto: LoginDto, @Headers('x-queueb-client') client?: string) {
    return this.authService.login(dto, authAuditContext(client));
  }

  // =====================================
  // CURRENT USER
  // Dilindungi JWT + pemeriksaan sesi
  // =====================================

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: AuthenticatedUser) {
    return this.profile.read(user.id);
  }

  // =====================================
  // REFRESH TOKEN
  // Maksimal 10 request per menit
  // =====================================

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @Throttle({
    default: {
      limit: 10,
      ttl: 60_000,
    },
  })
  refresh(
    @Body() dto: RefreshTokenDto,
    @Headers('x-queueb-client') client?: string,
  ) {
    return this.authService.refresh(dto, authAuditContext(client));
  }

  // =====================================
  // LOGOUT
  // Mencabut sesi pengguna
  // =====================================

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @Throttle({
    default: {
      limit: 30,
      ttl: 60_000,
    },
  })
  logout(
    @Body() dto: RefreshTokenDto,
    @Headers('x-queueb-client') client?: string,
  ) {
    return this.authService.logout(dto, authAuditContext(client));
  }
}
