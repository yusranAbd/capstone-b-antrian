import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import type { AuthenticatedUser } from './auth.types';
import { CurrentUser } from './decorators/current-user.decorator';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { PeranPengguna } from '../generated/prisma/client';
import { Roles } from './decorators/roles.decorator';
import { RolesGuard } from './guards/roles.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @HttpCode(HttpStatus.OK)
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(
    @CurrentUser()
    user: AuthenticatedUser,
  ) {
    return user;
  }

  @HttpCode(HttpStatus.OK)
  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto);
  }

  @HttpCode(HttpStatus.OK)
  @Post('logout')
  logout(@Body() dto: RefreshTokenDto) {
    return this.authService.logout(dto);
  }

  // Endpoint sementara untuk pengujian RBAC petugas
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(PeranPengguna.PETUGAS, PeranPengguna.ADMIN)
  @Get('cek-akses/petugas')
  cekAksesPetugas(@CurrentUser() user: AuthenticatedUser) {
    return {
      message: 'Akses petugas diizinkan',
      pengguna: user.email,
      peran: user.peran,
    };
  }

  // Endpoint sementara untuk pengujian RBAC admin
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(PeranPengguna.ADMIN)
  @Get('cek-akses/admin')
  cekAksesAdmin(@CurrentUser() user: AuthenticatedUser) {
    return {
      message: 'Akses admin diizinkan',
      pengguna: user.email,
      peran: user.peran,
    };
  }
}
