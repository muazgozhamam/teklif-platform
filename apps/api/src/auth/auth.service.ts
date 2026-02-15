import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

type AuthUser = { id: string; role: string };

type AuthTokens = {
  access_token: string;
  accessToken: string;
  refresh_token: string;
  refreshToken: string;
  token_type: 'Bearer';
  expires_in: number;
};

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private audit: AuditService,
    private cfg: ConfigService,
  ) {}

  async validateUser(email: string, password: string) {
    const ident = (email || '').toString().trim();
    if (!ident) return null;

    const user = await this.prisma.user.findUnique({
      where: { email: ident },
    });

    if (!user) return null;
    if (!user.password) return null;
    if (!user.isActive) {
      await this.audit.log({
        actorUserId: user.id,
        actorRole: user.role,
        action: 'LOGIN_DENIED_INACTIVE',
        entityType: 'AUTH',
        entityId: user.id,
        metaJson: { email: ident, reason: 'inactive' },
      });
      return null;
    }

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return null;

    return user;
  }
  private parseDurationToSeconds(raw: string): number {
    const input = String(raw ?? '').trim().toLowerCase();
    if (!input) return 900;
    if (/^\d+$/.test(input)) return Number(input);
    const m = input.match(/^(\d+)([smhd])$/);
    if (!m) return 900;
    const n = Number(m[1]);
    const unit = m[2];
    if (unit === 's') return n;
    if (unit === 'm') return n * 60;
    if (unit === 'h') return n * 3600;
    if (unit === 'd') return n * 86400;
    return 900;
  }

  private issueTokens(user: AuthUser): AuthTokens {
    const accessExpiresInRaw = this.cfg.get<string>('ACCESS_TOKEN_EXPIRES_IN') || '15m';
    const refreshExpiresInRaw = this.cfg.get<string>('REFRESH_TOKEN_EXPIRES_IN') || '7d';
    const accessExpiresIn = this.parseDurationToSeconds(accessExpiresInRaw);
    const refreshExpiresIn = this.parseDurationToSeconds(refreshExpiresInRaw);
    const refreshSecret = this.cfg.get<string>('JWT_REFRESH_SECRET') || this.cfg.get<string>('JWT_SECRET') || 'dev-secret';

    const access_token = this.jwt.sign({ sub: user.id, role: user.role }, { expiresIn: accessExpiresIn });
    const refresh_token = this.jwt.sign(
      { sub: user.id, role: user.role, tokenType: 'refresh' },
      { secret: refreshSecret, expiresIn: refreshExpiresIn },
    );

    return {
      access_token,
      accessToken: access_token,
      refresh_token,
      refreshToken: refresh_token,
      token_type: 'Bearer',
      expires_in: accessExpiresIn,
    };
  }

  async login(user: AuthUser): Promise<AuthTokens> {
    return this.issueTokens(user);
  }

  async refresh(refreshTokenRaw: string): Promise<AuthTokens> {
    const refreshToken = String(refreshTokenRaw ?? '').trim();
    if (!refreshToken) throw new UnauthorizedException('Invalid refresh token');

    const refreshSecret = this.cfg.get<string>('JWT_REFRESH_SECRET') || this.cfg.get<string>('JWT_SECRET') || 'dev-secret';
    let payload: { sub?: string; role?: string; tokenType?: string } | null = null;
    try {
      payload = this.jwt.verify(refreshToken, { secret: refreshSecret }) as {
        sub?: string;
        role?: string;
        tokenType?: string;
      };
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const userId = String(payload?.sub ?? '').trim();
    if (!userId) throw new UnauthorizedException('Invalid refresh token');
    if (payload?.tokenType && payload.tokenType !== 'refresh') {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, isActive: true },
    });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    return this.issueTokens({ id: user.id, role: user.role });
  }
}
