import {
  IsBoolean,
  IsString,
  IsUUID,
  Matches,
  ValidateIf,
} from 'class-validator';

export class UpdatePenugasanPetugasDto {
  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsUUID('4')
  petugasId?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsUUID('4')
  loketId?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  tanggalMulai?: string;

  // null diperbolehkan untuk menghapus batas akhir.
  @ValidateIf((_, value: unknown) => value !== undefined && value !== null)
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  tanggalSelesai?: string | null;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsBoolean()
  aktif?: boolean;
}
