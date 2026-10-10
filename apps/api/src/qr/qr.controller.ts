import {
  Controller,
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

import { QrService } from './qr.service';

@Controller('tiket')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(PeranPengguna.USER)
export class QrController {
  constructor(private readonly qrService: QrService) {}

  // POST /api/v1/tiket/:id/qr
  @Post(':id/qr')
  terbitkan(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.qrService.terbitkan(id, user.id);
  }
}
