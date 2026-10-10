import { IsString, IsUUID, Matches } from 'class-validator';

export class ProsesCheckInDto {
  @IsString()
  @Matches(/^SQ1\.[A-Za-z0-9_-]{43}$/, {
    message: 'Format QR Check-In tidak valid',
  })
  qrPayload!: string;

  @IsUUID('4', {
    message: 'loketId harus berupa UUID yang valid',
  })
  loketId!: string;
}
