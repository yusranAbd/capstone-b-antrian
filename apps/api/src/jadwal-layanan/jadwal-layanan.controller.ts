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

import { CreateJadwalLayananDto } from './dto/create-jadwal-layanan.dto';
import { UpdateJadwalLayananDto } from './dto/update-jadwal-layanan.dto';
import { JadwalLayananService } from './jadwal-layanan.service';

@Controller('jadwal-layanan')
@UseGuards(JwtAuthGuard, RolesGuard)
export class JadwalLayananController {
  constructor(private readonly jadwalService: JadwalLayananService) {}

  // CREATE - ADMIN
  @Post()
  @Roles(PeranPengguna.ADMIN)
  create(@Body() dto: CreateJadwalLayananDto) {
    return this.jadwalService.create(dto);
  }

  // READ ALL - SEMUA PENGGUNA LOGIN
  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.jadwalService.findAll(user.peran);
  }

  // READ ONE - SEMUA PENGGUNA LOGIN
  @Get(':id')
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.jadwalService.findOne(id, user.peran);
  }

  // UPDATE - ADMIN
  @Patch(':id')
  @Roles(PeranPengguna.ADMIN)
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateJadwalLayananDto,
  ) {
    return this.jadwalService.update(id, dto);
  }

  // SOFT DELETE - ADMIN
  @Delete(':id')
  @Roles(PeranPengguna.ADMIN)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.jadwalService.remove(id);
  }
}
