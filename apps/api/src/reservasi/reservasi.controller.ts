import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';

import type { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

import { PeranPengguna } from '../generated/prisma/client';

import { CreateReservasiDto } from './dto/create-reservasi.dto';
import { ReservasiService } from './reservasi.service';

@Controller('reservasi')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(PeranPengguna.USER)
export class ReservasiController {
  constructor(private readonly reservasiService: ReservasiService) {}

  @Post()
  create(
    @Body() dto: CreateReservasiDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.reservasiService.create(dto, user.id);
  }

  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.reservasiService.findAll(user.id);
  }

  @Get(':id')
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.reservasiService.findOne(id, user.id);
  }
}
