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

import { CreateLoketDto } from './dto/create-loket.dto';
import { UpdateLoketDto } from './dto/update-loket.dto';
import { LoketService } from './loket.service';

@Controller('loket')
@UseGuards(JwtAuthGuard, RolesGuard)
export class LoketController {
  constructor(private readonly loketService: LoketService) {}

  // CREATE - ADMIN
  @Post()
  @Roles(PeranPengguna.ADMIN)
  create(@Body() dto: CreateLoketDto) {
    return this.loketService.create(dto);
  }

  // READ ALL - PENGGUNA LOGIN
  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.loketService.findAll(user.peran);
  }

  // READ ONE - PENGGUNA LOGIN
  @Get(':id')
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.loketService.findOne(id, user.peran);
  }

  // UPDATE - ADMIN
  @Patch(':id')
  @Roles(PeranPengguna.ADMIN)
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateLoketDto) {
    return this.loketService.update(id, dto);
  }

  // SOFT DELETE - ADMIN
  @Delete(':id')
  @Roles(PeranPengguna.ADMIN)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.loketService.remove(id);
  }
}
