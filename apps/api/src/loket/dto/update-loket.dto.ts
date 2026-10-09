import {
  IsBoolean,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class UpdateLoketDto {
  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsUUID('4')
  layananId?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsString()
  @MinLength(2)
  @MaxLength(20)
  @Matches(/^[A-Z0-9]+(?:-[A-Z0-9]+)*$/)
  kode?: string;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsString()
  @MinLength(3)
  @MaxLength(100)
  @Matches(/\S/)
  nama?: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  lokasi?: string | null;

  @ValidateIf((_, value: unknown) => value !== undefined)
  @IsBoolean()
  aktif?: boolean;
}
