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

import { CreatePenugasanPetugasDto } from './dto/create-penugasan-petugas.dto';
import { UpdatePenugasanPetugasDto } from './dto/update-penugasan-petugas.dto';
import { PenugasanPetugasService } from './penugasan-petugas.service';

@Controller('penugasan-petugas')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PenugasanPetugasController {
  constructor(private readonly service: PenugasanPetugasService) {}

  @Post()
  @Roles(PeranPengguna.ADMIN)
  create(@Body() dto: CreatePenugasanPetugasDto) {
    return this.service.create(dto);
  }

  @Get()
  @Roles(PeranPengguna.ADMIN, PeranPengguna.PETUGAS)
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.service.findAll(user.peran, user.id);
  }

  @Get(':id')
  @Roles(PeranPengguna.ADMIN, PeranPengguna.PETUGAS)
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.service.findOne(id, user.peran, user.id);
  }

  @Patch(':id')
  @Roles(PeranPengguna.ADMIN)
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePenugasanPetugasDto,
  ) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  @Roles(PeranPengguna.ADMIN)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.remove(id);
  }
}
