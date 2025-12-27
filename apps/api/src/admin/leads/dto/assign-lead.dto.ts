import { IsString } from 'class-validator';

export class AssignLeadDto {
  @IsString()
  userId: string;
}

