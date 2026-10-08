import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import type { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

import { PeranPengguna } from '../generated/prisma/client';

import { CreateLayananDto } from './dto/create-layanan.dto';
import { UpdateLayananDto } from './dto/update-layanan.dto';
import { LayananService } from './layanan.service';

@Controller('layanan')
@UseGuards(JwtAuthGuard, RolesGuard)
export class LayananController {
  constructor(private readonly layananService: LayananService) {}

  // =====================================
  // CREATE - ADMIN
  // =====================================

  @Post()
  @Roles(PeranPengguna.ADMIN)
  create(@Body() dto: CreateLayananDto) {
    return this.layananService.create(dto);
  }

  // =====================================
  // READ ALL - AUTHENTICATED USERS
  // =====================================

  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.layananService.findAll(user.peran);
  }

  // =====================================
  // READ ONE - AUTHENTICATED USERS
  // =====================================

  @Get(':id')
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.layananService.findOne(id, user.peran);
  }

  // =====================================
  // UPDATE - ADMIN
  // =====================================

  @Patch(':id')
  @Roles(PeranPengguna.ADMIN)
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateLayananDto,
  ) {
    return this.layananService.update(id, dto);
  }

  // =====================================
  // SOFT DELETE - ADMIN
  // =====================================

  @Delete(':id')
  @Roles(PeranPengguna.ADMIN)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.layananService.remove(id);
  }
}
