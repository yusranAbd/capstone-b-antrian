import { IsEnum, IsInt, IsString, IsUUID, Matches, Min } from 'class-validator';

import { HariLayanan } from '../../generated/prisma/client';

export class CreateJadwalLayananDto {
  @IsUUID('4', {
    message: 'layananId harus berupa UUID yang valid',
  })
  layananId!: string;

  @IsEnum(HariLayanan, {
    message: 'Hari harus salah satu dari SENIN sampai MINGGU',
  })
  hari!: HariLayanan;

  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'jamBuka harus menggunakan format HH:mm',
  })
  jamBuka!: string;

  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'jamTutup harus menggunakan format HH:mm',
  })
  jamTutup!: string;

  @IsInt({
    message: 'kapasitasHarian harus berupa bilangan bulat',
  })
  @Min(1, {
    message: 'kapasitasHarian minimal 1',
  })
  kapasitasHarian!: number;
}
