import { IsIn } from 'class-validator';
import { PanggilBerikutnyaDto } from './panggil-berikutnya.dto';

export const ALASAN_PEMBATALAN_SESI = [
  'LAYANAN_TIDAK_DAPAT_DILANJUTKAN',
  'DOKTER_BERHALANGAN',
  'PASIEN_MEMILIH_BATAL',
] as const;

export class BatalkanSesiBerakhirDto extends PanggilBerikutnyaDto {
  @IsIn(ALASAN_PEMBATALAN_SESI)
  alasan!: (typeof ALASAN_PEMBATALAN_SESI)[number];
}
