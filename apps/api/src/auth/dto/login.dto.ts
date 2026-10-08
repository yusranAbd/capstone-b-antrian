import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';

export class LoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  kataSandi!: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  namaPerangkat?: string;
}
