import { Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';

export type AuthAction =
  'LOGIN' | 'REFRESH' | 'LOGOUT' | 'CABUT_SESI' | 'BACA_AUDIT';
export type AuditReason =
  | 'OK'
  | 'CREDENTIALS_REJECTED'
  | 'SESSION_REJECTED'
  | 'AUTH_ERROR'
  | 'PASSWORD_CHANGED'
  | 'ACCOUNT_DISABLED'
  | 'AUDIT_READ';
export interface AuthAuditContext {
  requestId: string;
  klien: string;
  akunRef?: string;
  sesiRef?: string;
  aktorRef?: string;
}
const clients = new Set(['WEB', 'ANDROID', 'IOS', 'DESKTOP']);
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
export function authAuditContext(client?: string): AuthAuditContext {
  return {
    requestId: randomUUID(),
    klien: clients.has(client ?? '') ? client! : 'UNKNOWN',
  };
}

/** Fail-open audit, isolated from auth/CAS. Never serialize requests or exceptions. */
@Injectable()
export class AuthAuditService {
  private readonly logger = new Logger(AuthAuditService.name);
  private cleanupAfter = 0;
  constructor(private readonly prisma: PrismaService) {}

  async record(
    aksi: AuthAction,
    context: AuthAuditContext,
    hasil: 'BERHASIL' | 'DITOLAK' | 'ERROR',
    alasan: AuditReason,
    jumlahSesi?: number | null,
  ) {
    const safeRef = (v: unknown) =>
      typeof v === 'string' && uuid.test(v) ? v : null;
    const cleanup = Date.now() >= this.cleanupAfter;
    if (cleanup) this.cleanupAfter = Date.now() + 3600000;
    try {
      await this.prisma.$transaction(
        async (tx) => {
          if (cleanup)
            await tx.auditSesi.deleteMany({
              where: {
                terjadiPada: { lt: new Date(Date.now() - 30 * 86400000) },
              },
            });
          await tx.auditSesi.create({
            data: {
              requestId: safeRef(context.requestId) ?? randomUUID(),
              akunRef: safeRef(context.akunRef),
              aktorRef: safeRef(
                context.aktorRef ??
                  (hasil === 'BERHASIL' ? context.akunRef : undefined),
              ),
              sesiRef: safeRef(context.sesiRef),
              aksi,
              hasil,
              alasan,
              klien: clients.has(context.klien) ? context.klien : 'UNKNOWN',
              sumber: 'UNKNOWN',
              jumlahSesi:
                Number.isSafeInteger(jumlahSesi) && jumlahSesi! >= 0
                  ? jumlahSesi
                  : null,
            },
          });
        },
        { maxWait: 500, timeout: 1000 },
      );
    } catch {
      this.logger.warn(
        'AUDIT_SINK_UNAVAILABLE: aktivitas sesi tidak tercatat; hasil autentikasi dipertahankan',
      );
    }
  }

  async recordRevocation(
    penggunaId: string,
    aktorId: string,
    reason: 'PASSWORD_CHANGED' | 'ACCOUNT_DISABLED',
    count: number | null,
  ) {
    try {
      const users = await this.prisma.pengguna.findMany({
        where: { id: { in: [penggunaId, aktorId] } },
        select: { id: true, auditRef: true },
      });
      const context = authAuditContext();
      context.akunRef = users.find((u) => u.id === penggunaId)?.auditRef;
      context.aktorRef = users.find((u) => u.id === aktorId)?.auditRef;
      await this.record('CABUT_SESI', context, 'BERHASIL', reason, count);
    } catch {
      this.logger.warn(
        'AUDIT_SINK_UNAVAILABLE: pencabutan sesi tidak tercatat',
      );
    }
  }
}
