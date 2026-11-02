import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { KategoriLayanan } from '../../generated/prisma/client';

export class UpdateLayananDto {
  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsEnum(KategoriLayanan)
  kategori?: KategoriLayanan;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsString()
  @Matches(/^[A-Z0-9]{2,20}$/)
  kode?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsString()
  @MinLength(3)
  @MaxLength(150)
  @Matches(/\S/)
  nama?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  deskripsi?: string | null;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsString()
  @Matches(/^[A-Z]{1,5}$/)
  prefixAntrean?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsInt()
  @Min(1)
  @Max(240)
  durasiDasarMenit?: number;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsBoolean()
  aktif?: boolean;
}
