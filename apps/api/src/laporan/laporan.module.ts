import {
  Controller,
  Get,
  Header,
  Module,
  Query,
  UseGuards,
} from '@nestjs/common';
import { IsOptional, IsUUID } from 'class-validator';
import { AuthModule } from '../auth/auth.module';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { PeranPengguna } from '../generated/prisma/client';
import { PrismaModule } from '../prisma/prisma.module';
import { PeriodQuery } from './period-query';
import { LaporanService } from './laporan.service';

export class ReportQuery extends PeriodQuery {
  @IsOptional() @IsUUID('4') layananId?: string;
}
@Controller('laporan')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(PeranPengguna.ADMIN)
export class LaporanController {
  constructor(private readonly service: LaporanService) {}
  @Get('operasional')
  @Header('Cache-Control', 'no-store')
  report(@Query() query: ReportQuery) {
    return this.service.read(query);
  }
}
@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [LaporanController],
  providers: [LaporanService],
})
export class LaporanModule {}
