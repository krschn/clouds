import { IsInt, IsOptional, IsString, Min, MaxLength } from 'class-validator';

export class CreatePaymentDto {
  @IsString()
  @MaxLength(80)
  label: string;

  @IsInt()
  @Min(1)
  amountCentavos: number;

  @IsOptional()
  @IsString()
  source?: string;

  /** Supply this from any external feed so replays are idempotent. */
  @IsOptional()
  @IsString()
  externalRef?: string;
}
