
import {
  IsOptional,
  IsString,
  IsUUID,
  Matches,
} from 'class-validator';

export class CreatePenugasanPetugasDto {
  @IsUUID('4', {
    message: 'petugasId harus berupa UUID yang valid',
  })
  petugasId!: string;

  @IsUUID('4', {
    message: 'loketId harus berupa UUID yang valid',
  })
  loketId!: string;

  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message:
      'tanggalMulai harus menggunakan format YYYY-MM-DD',
  })
  tanggalMulai!: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message:
      'tanggalSelesai harus menggunakan format YYYY-MM-DD',
  })
  tanggalSelesai?: string | null;
}
