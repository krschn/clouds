import { IsInt, IsISO8601, IsOptional, Min } from 'class-validator';

export class CreateMonthDto {
  @IsISO8601()
  period: string;

  /** Rough expected total, used only to suggest a denominator. */
  @IsOptional()
  @IsInt()
  @Min(0)
  expectedTotalCentavos?: number;

  /** Set this to override the suggestion entirely. */
  @IsOptional()
  @IsInt()
  @Min(1)
  centavosPerCloud?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  maxClouds?: number;
}
