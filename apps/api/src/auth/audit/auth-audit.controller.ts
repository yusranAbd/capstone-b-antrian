import {
  Controller,
  Get,
  Header,
  Headers,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { CurrentUser } from '../decorators/current-user.decorator';
import { Roles } from '../decorators/roles.decorator';
import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { RolesGuard } from '../guards/roles.guard';
import type { AuthenticatedUser } from '../auth.types';
import { PeranPengguna, Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PeriodQuery, period } from '../../laporan/period-query';
import { AuthAuditService, authAuditContext } from './auth-audit.service';

export class SessionAuditQuery extends PeriodQuery {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100000) halaman = 1;
  @IsOptional()
  @IsIn(['LOGIN', 'REFRESH', 'LOGOUT', 'CABUT_SESI', 'BACA_AUDIT'])
  aksi?: string;
  @IsOptional() @IsIn(['BERHASIL', 'DITOLAK', 'ERROR']) hasil?: string;
  @IsOptional() @IsUUID() akunRef?: string;
  @IsOptional() @IsUUID() sesiRef?: string;
}
@Controller('audit-sesi')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(PeranPengguna.ADMIN)
export class AuthAuditController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuthAuditService,
  ) {}
  @Get()
  @Header('Cache-Control', 'no-store')
  async list(
    @Query() query: SessionAuditQuery,
    @CurrentUser() user: AuthenticatedUser,
    @Headers('x-queueb-client') client?: string,
  ) {
    const dates = period(query);
    const where = {
      terjadiPada: {
        gte: new Date(
          Math.max(dates.mulai.getTime(), Date.now() - 30 * 86400000),
        ),
        lt: new Date(dates.selesai.getTime() + 86400000),
      },
      aksi: query.aksi,
      hasil: query.hasil,
      akunRef: query.akunRef,
      sesiRef: query.sesiRef,
    };
    const result = await this.prisma.$transaction(
      async (tx) => {
        const [total, data] = await Promise.all([
          tx.auditSesi.count({ where }),
          tx.auditSesi.findMany({
            where,
            orderBy: [{ terjadiPada: 'desc' }, { id: 'desc' }],
            take: 30,
            skip: (query.halaman - 1) * 30,
          }),
        ]);
        return {
          total,
          halaman: query.halaman,
          jumlahHalaman: Math.max(1, Math.ceil(total / 30)),
          zonaWaktu: 'UTC',
          retensiHari: 30,
          data,
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    try {
      const actor = await this.prisma.pengguna.findUnique({
        where: { id: user.id },
        select: { auditRef: true },
      });
      const context = authAuditContext(client);
      context.akunRef = actor?.auditRef;
      await this.audit.record('BACA_AUDIT', context, 'BERHASIL', 'AUDIT_READ');
    } catch {
      /* Audit sink cannot change a completed read. */
    }
    return result;
  }
}
