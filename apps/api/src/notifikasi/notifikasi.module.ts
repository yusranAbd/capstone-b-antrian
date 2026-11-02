import {
  Controller,
  Get,
  Header,
  Module,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { AuthModule } from '../auth/auth.module';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth.types';
import { PeranPengguna } from '../generated/prisma/client';
import { PrismaModule } from '../prisma/prisma.module';
import { NotifikasiService } from './notifikasi.service';

export class NotificationQuery {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100000)
  halaman = 1;
}

@Controller('notifikasi')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(PeranPengguna.USER)
export class NotifikasiController {
  constructor(private readonly service: NotifikasiService) {}
  @Get('saya')
  @Header('Cache-Control', 'no-store')
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: NotificationQuery,
  ) {
    return this.service.list(user.id, query.halaman);
  }
  @Patch(':id/baca')
  read(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.service.read(user.id, id);
  }
}

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [NotifikasiController],
  providers: [NotifikasiService],
})
export class NotifikasiModule {}
