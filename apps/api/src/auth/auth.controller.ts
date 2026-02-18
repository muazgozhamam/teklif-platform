import {
  Body,
  ConflictException,
  Controller,
  Get,
  Post,
  Req,
  Res,
  UseGuards,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { GoogleAuthGuard } from './google-auth.guard';
import type { Response } from 'express';
type ReqWithUser = {
  user?: { sub?: string; role?: string; iat?: number; exp?: number };
};

type OAuthReq = {
  user?: { email?: string; name?: string };
  query?: { state?: string };
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

  @Post('register')
  async register(
    @Body() body: { email?: string; password?: string; name?: string },
  ) {
    const email = (body.email ?? '').toString().trim();
    const password = (body.password ?? '').toString();
    const name = (body.name ?? '').toString().trim();

    if (!email || !password) {
      throw new UnauthorizedException('E-posta ve şifre zorunlu');
    }

    try {
      return await this.auth.register({ email, password, name });
    } catch (err) {
      if (err instanceof ConflictException) throw err;
      throw err;
    }
  }

  // Token doğrulama + payload görme
  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: ReqWithUser) {
    return req.user; // { sub, role, iat, exp }
  }

  @Get('google')
  @UseGuards(GoogleAuthGuard)
  googleAuth() {
    return;
  }

  @Get('google/callback')
  @UseGuards(GoogleAuthGuard)
  async googleCallback(@Req() req: OAuthReq, @Res() res: Response) {
    const oauthUser = req.user;
    if (!oauthUser?.email) {
      throw new UnauthorizedException('Google authentication failed');
    }

    const user = await this.auth.findOrCreateGoogleUser({
      email: oauthUser.email,
      name: oauthUser.name,
    });
    const accessToken = this.auth.signAccessToken(user.id, user.role);
    const redirectBase = this.auth.resolveOAuthRedirect(req.query?.state);
    const separator = redirectBase.includes('?') ? '&' : '?';
    const redirectUrl = `${redirectBase}${separator}access_token=${encodeURIComponent(accessToken)}`;

    // API domain cookie (httpOnly); dashboard query token'u localStorage'a alır.
    res.cookie('satdedi_access_token', accessToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 7 * 24 * 60 * 60 * 1000,
    });

    return res.redirect(302, redirectUrl);
  }
}
