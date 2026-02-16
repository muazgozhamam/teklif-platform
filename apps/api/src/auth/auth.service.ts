import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { randomBytes } from 'crypto';

const DEV_JWT_SECRET = 'dev-secret';
const STATE_SECRET = process.env.OAUTH_STATE_SECRET || process.env.JWT_SECRET || DEV_JWT_SECRET;
const FALLBACK_REDIRECT = process.env.DASHBOARD_BASE_URL || 'http://localhost:3002/login';
const DEFAULT_ALLOWED_REDIRECTS = [
  'http://localhost:3002/login',
  'https://stage.satdedi.com/login',
  'https://app.satdedi.com/login',
];

type GoogleUser = {
  email: string;
  name?: string;
  provider?: 'google';
  providerId?: string;
};


@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  async validateUser(email: string, password: string) {
    const ident = (email || '').toString().trim();
    if (!ident) return null;

    const user = await this.prisma.user.findUnique({
      where: { email: ident },
    });

    if (!user) return null;
    if (!user.password) return null;

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return null;

    return user;
  }
  async login(user: { id: string; role: string }) {
    return {
      access_token: this.signAccessToken(user.id, user.role),
    };
  }

  signAccessToken(id: string, role: string) {
    return this.jwt.sign({ sub: id, role }, { secret: process.env.JWT_SECRET || DEV_JWT_SECRET });
  }

  createOAuthState(redirect?: string) {
    const redirectUrl = this.sanitizeRedirect(redirect);
    return this.jwt.sign(
      {
        redirect: redirectUrl,
        nonce: randomBytes(16).toString('hex'),
      },
      { secret: STATE_SECRET, expiresIn: '10m' },
    );
  }

  resolveOAuthRedirect(state?: string) {
    if (!state) return this.sanitizeRedirect(undefined);
    try {
      const payload = this.jwt.verify(state, { secret: STATE_SECRET }) as { redirect?: string };
      return this.sanitizeRedirect(payload?.redirect);
    } catch {
      return this.sanitizeRedirect(undefined);
    }
  }

  private allowedRedirects() {
    const fromEnv = String(process.env.OAUTH_ALLOWED_REDIRECTS || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    return fromEnv.length ? fromEnv : DEFAULT_ALLOWED_REDIRECTS;
  }

  private sanitizeRedirect(redirect?: string) {
    const fallback = FALLBACK_REDIRECT;
    if (!redirect) return fallback;
    try {
      const parsed = new URL(redirect);
      const normalized = `${parsed.origin}${parsed.pathname}`;
      const allowed = this.allowedRedirects();
      if (allowed.includes(normalized)) return normalized;
      return fallback;
    } catch {
      return fallback;
    }
  }

  async findOrCreateGoogleUser(input: GoogleUser) {
    const email = String(input.email || '').trim().toLowerCase();
    if (!email) {
      throw new UnauthorizedException('Google email required');
    }

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) return existing;

    // Schema password zorunlu olduğu için rastgele hash üretiyoruz.
    const tempPasswordHash = await bcrypt.hash(randomBytes(24).toString('hex'), 10);

    return this.prisma.user.create({
      data: {
        email,
        name: input.name || email.split('@')[0],
        password: tempPasswordHash,
      },
    });
  }
}
