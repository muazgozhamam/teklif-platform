import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  function buildService(overrides?: {
    verifyImpl?: (token: string, opts: any) => any;
    userById?: any;
  }) {
    const jwt = {
      sign: jest.fn((payload: any, opts?: any) => `token.${payload.sub}.${String(opts?.expiresIn ?? 'na')}`),
      verify: jest.fn(overrides?.verifyImpl ?? (() => ({ sub: 'u-1', role: 'ADMIN', tokenType: 'refresh' }))),
    };

    const prisma = {
      user: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where?.id) return overrides?.userById ?? { id: 'u-1', role: 'ADMIN', isActive: true };
          return null;
        }),
      },
    };

    const audit = { log: jest.fn(async () => ({ ok: true })) };
    const cfg = {
      get: jest.fn((key: string) => {
        if (key === 'ACCESS_TOKEN_EXPIRES_IN') return '15m';
        if (key === 'REFRESH_TOKEN_EXPIRES_IN') return '7d';
        if (key === 'JWT_SECRET') return 'dev-secret';
        if (key === 'JWT_REFRESH_SECRET') return 'refresh-secret';
        return undefined;
      }),
    };

    const service = new AuthService(prisma as any, jwt as any, audit as any, cfg as any);
    return { service, jwt, prisma };
  }

  it('login returns access + refresh token contract', async () => {
    const { service } = buildService();
    const out = await service.login({ id: 'u-1', role: 'ADMIN' });
    expect(out.access_token).toBeTruthy();
    expect(out.accessToken).toBe(out.access_token);
    expect(out.refresh_token).toBeTruthy();
    expect(out.refreshToken).toBe(out.refresh_token);
    expect(out.token_type).toBe('Bearer');
    expect(out.expires_in).toBe(900);
  });

  it('refresh returns new tokens for active user', async () => {
    const { service } = buildService();
    const out = await service.refresh('some-refresh-token');
    expect(out.access_token).toContain('token.u-1');
    expect(out.refresh_token).toContain('token.u-1');
  });

  it('refresh rejects invalid token', async () => {
    const { service } = buildService({
      verifyImpl: () => {
        throw new Error('bad token');
      },
    });
    await expect(service.refresh('bad')).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('refresh rejects inactive user', async () => {
    const { service } = buildService({ userById: { id: 'u-1', role: 'ADMIN', isActive: false } });
    await expect(service.refresh('some-refresh-token')).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
