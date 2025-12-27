import { ApiProperty } from '@nestjs/swagger';

export class LeadAnswerDto {
  @ApiProperty({ example: 'city' })
  key: string;

  @ApiProperty({ example: 'Konya' })
  answer: string;
}

export class WizardAnswerDto {
  @ApiProperty({ example: 'Konya' })
  key?: string;
  answer: string;
}
