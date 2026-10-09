import {
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateLoketDto {
  @IsUUID('4', {
    message: 'layananId harus berupa UUID yang valid',
  })
  layananId!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(20)
  @Matches(/^[A-Z0-9]+(?:-[A-Z0-9]+)*$/, {
    message:
      'Kode loket hanya boleh menggunakan huruf kapital, angka, dan tanda hubung',
  })
  kode!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(100)
  @Matches(/\S/, {
    message: 'Nama loket tidak boleh kosong',
  })
  nama!: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  lokasi?: string | null;
}
