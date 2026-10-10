import { IsString, IsUUID, Matches } from 'class-validator';

export class CreateReservasiDto {
  @IsUUID('4', {
    message: 'layananId harus berupa UUID yang valid',
  })
  layananId!: string;

  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'tanggalAntrean harus berformat YYYY-MM-DD',
  })
  tanggalAntrean!: string;
}
