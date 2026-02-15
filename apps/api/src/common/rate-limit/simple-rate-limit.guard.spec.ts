import { TooManyRequestsException } from '@nestjs/common';
import { SimpleRateLimitGuard } from './simple-rate-limit.guard';

describe('SimpleRateLimitGuard', () => {
  function buildGuard(overrides?: { env?: Record<string, string> }) {
    const cfg = {
      get: jest.fn((key: string) => overrides?.env?.[key]),
    };
    const guard = new SimpleRateLimitGuard(cfg as any);
    return { guard };
  }

  function ctx(path: string, ip = '127.0.0.1') {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ path, ip, headers: {} }),
      }),
    } as any;
  }

  it('allows requests when rate limit disabled', () => {
    const { guard } = buildGuard({ env: { RATE_LIMIT_ENABLED: '0' } });
    expect(guard.canActivate(ctx('/auth/login'))).toBe(true);
    expect(guard.canActivate(ctx('/auth/login'))).toBe(true);
  });

  it('enforces auth-specific limit', () => {
    const { guard } = buildGuard({
      env: {
        RATE_LIMIT_ENABLED: '1',
        RATE_LIMIT_WINDOW_MS: '60000',
        RATE_LIMIT_AUTH_MAX: '2',
      },
    });

    expect(guard.canActivate(ctx('/auth/login'))).toBe(true);
    expect(guard.canActivate(ctx('/auth/login'))).toBe(true);
    expect(() => guard.canActivate(ctx('/auth/login'))).toThrow(TooManyRequestsException);
  });

  it('uses global limit for non-auth routes', () => {
    const { guard } = buildGuard({
      env: {
        RATE_LIMIT_ENABLED: '1',
        RATE_LIMIT_WINDOW_MS: '60000',
        RATE_LIMIT_MAX: '1',
      },
    });

    expect(guard.canActivate(ctx('/deals/inbox/mine'))).toBe(true);
    expect(() => guard.canActivate(ctx('/deals/inbox/mine'))).toThrow(TooManyRequestsException);
  });

  it('skips health route', () => {
    const { guard } = buildGuard({
      env: {
        RATE_LIMIT_ENABLED: '1',
        RATE_LIMIT_MAX: '1',
      },
    });

    expect(guard.canActivate(ctx('/health'))).toBe(true);
    expect(guard.canActivate(ctx('/health'))).toBe(true);
  });
});
