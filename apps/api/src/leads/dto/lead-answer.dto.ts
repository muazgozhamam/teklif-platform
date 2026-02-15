import { IsOptional, IsString, IsNotEmpty } from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class LeadAnswerDto {
  /**
   * Canonical field name used by API.
   * Accepts legacy/alternate `field` and maps it into `key` before validation.
   */
  @ApiProperty({ required: true, example: 'city' })
  @Transform(({ value, obj }) => (value ?? obj?.field ?? '').toString().trim())
  @IsString()
  @IsNotEmpty()
  key!: string;

  /**
   * Legacy/alternate name; optional.
   */
  @ApiProperty({ required: false, example: 'city' })
  @Transform(({ value }) => (value == null ? undefined : value.toString()))
  @IsOptional()
  @IsString()
  field?: string;

  /**
   * Answer value (required).
   */
  @ApiProperty({ required: true, example: 'Konya' })
  @Transform(({ value }) => (value ?? '').toString().trim())
  @IsString()
  @IsNotEmpty()
  answer!: string;
}
