import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  UseGuards,
} from '@nestjs/common';

import type { AuthenticatedUser } from '../auth/auth.types';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

import { PeranPengguna } from '../generated/prisma/client';

import { TiketService } from './tiket.service';

@Controller('tiket')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(PeranPengguna.USER)
export class TiketController {
  constructor(private readonly tiketService: TiketService) {}

  // Daftar tiket milik pengguna.
  // Route statis harus berada sebelum :id.
  @Get('saya')
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.tiketService.findAll(user.id);
  }

  // Detail tiket berdasarkan UUID.
  @Get(':id')
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.tiketService.findOne(id, user.id);
  }
}
