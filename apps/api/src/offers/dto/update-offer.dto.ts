import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class UpdateOfferDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  amount?: number;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsString()
  description?: string;
}

