import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsEmail()
  identifier?: string;

  @IsString()
  @MinLength(1)
  password!: string;
}
