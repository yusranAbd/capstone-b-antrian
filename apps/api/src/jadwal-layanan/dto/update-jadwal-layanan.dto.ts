import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsString,
  IsUUID,
  Matches,
  Min,
  ValidateIf,
} from 'class-validator';

import { HariLayanan } from '../../generated/prisma/client';

export class UpdateJadwalLayananDto {
  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsUUID('4')
  layananId?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsEnum(HariLayanan)
  hari?: HariLayanan;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'jamBuka harus menggunakan format HH:mm',
  })
  jamBuka?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'jamTutup harus menggunakan format HH:mm',
  })
  jamTutup?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsInt()
  @Min(1)
  kapasitasHarian?: number;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsBoolean()
  aktif?: boolean;
}
