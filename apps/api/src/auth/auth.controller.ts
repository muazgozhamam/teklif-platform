import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
type ReqWithUser = {
  user?: { sub?: string; role?: string; iat?: number; exp?: number };
};

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}
  @Post('login')
  async login(
    @Body() body: { identifier?: string; email?: string; password: string },
  ) {
    const ident = (body.identifier ?? body.email ?? '').toString().trim();
    if (!ident) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const user = await this.auth.validateUser(ident, body.password);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.auth.login({ id: user.id, role: user.role });
  }

  // Token doğrulama + payload görme
  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: ReqWithUser) {
    return req.user; // { sub, role, iat, exp }
  }
}
