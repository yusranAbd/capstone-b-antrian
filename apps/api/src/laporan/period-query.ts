import { BadRequestException } from '@nestjs/common';
import { IsString } from 'class-validator';
import { validPatientQueueDate } from '../layanan/dto/patient-queue-query.dto';

export class PeriodQuery {
  @IsString() mulai!: string;
  @IsString() selesai!: string;
}
export function period(query: PeriodQuery) {
  if (
    !validPatientQueueDate(query.mulai) ||
    !validPatientQueueDate(query.selesai)
  )
    throw new BadRequestException('Gunakan tanggal YYYY-MM-DD yang valid');
  const mulai = new Date(`${query.mulai}T00:00:00Z`),
    selesai = new Date(`${query.selesai}T00:00:00Z`);
  if (selesai < mulai || selesai.getTime() - mulai.getTime() > 30 * 86400000)
    throw new BadRequestException(
      'Periode maksimal 31 hari, tanggal akhir tidak boleh mendahului tanggal awal',
    );
  return { mulai, selesai };
}
