import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

type CounterEntry = {
  count: number;
  resetAt: number;
};

@Injectable()
export class SimpleRateLimitGuard implements CanActivate {
  private readonly counters = new Map<string, CounterEntry>();

  constructor(private readonly cfg: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<{
      ip?: string;
      path?: string;
      originalUrl?: string;
      method?: string;
      headers?: Record<string, string | string[] | undefined>;
    }>();

    if (!this.isEnabled()) return true;

    const routePath = String(req.path ?? req.originalUrl ?? '').split('?')[0] || '/';
    if (routePath === '/health' || routePath === '/_health' || routePath === '/docs') return true;

    const ip = this.getClientIp(req);
    const now = Date.now();
    const windowMs = this.getWindowMs();
    const max = this.getMaxForRoute(routePath);

    const key = `${routePath}:${ip}`;
    const existing = this.counters.get(key);

    if (!existing || existing.resetAt <= now) {
      this.counters.set(key, { count: 1, resetAt: now + windowMs });
      this.maybeCleanup(now);
      return true;
    }

    if (existing.count >= max) {
      throw new HttpException(`Rate limit exceeded for ${routePath}. Try again later.`, HttpStatus.TOO_MANY_REQUESTS);
    }

    existing.count += 1;
    this.counters.set(key, existing);
    this.maybeCleanup(now);
    return true;
  }

  private isEnabled(): boolean {
    const raw = String(this.cfg.get<string>('RATE_LIMIT_ENABLED') ?? '1').trim().toLowerCase();
    return ['1', 'true', 'yes', 'on'].includes(raw);
  }

  private getWindowMs(): number {
    const raw = Number(this.cfg.get<string>('RATE_LIMIT_WINDOW_MS') ?? 60_000);
    if (!Number.isFinite(raw) || raw <= 0) return 60_000;
    return Math.floor(raw);
  }

  private getGlobalMax(): number {
    const raw = Number(this.cfg.get<string>('RATE_LIMIT_MAX') ?? 300);
    if (!Number.isFinite(raw) || raw <= 0) return 300;
    return Math.floor(raw);
  }

  private getAuthMax(): number {
    const raw = Number(this.cfg.get<string>('RATE_LIMIT_AUTH_MAX') ?? 30);
    if (!Number.isFinite(raw) || raw <= 0) return 30;
    return Math.floor(raw);
  }

  private getMaxForRoute(path: string): number {
    if (path === '/auth/login' || path === '/auth/refresh') return this.getAuthMax();
    return this.getGlobalMax();
  }

  private getClientIp(req: {
    ip?: string;
    headers?: Record<string, string | string[] | undefined>;
  }): string {
    const xfwd = req.headers?.['x-forwarded-for'];
    const forwarded = Array.isArray(xfwd) ? xfwd[0] : xfwd;
    if (forwarded) {
      const first = String(forwarded).split(',')[0]?.trim();
      if (first) return first;
    }
    return String(req.ip ?? 'unknown').trim() || 'unknown';
  }

  private maybeCleanup(now: number) {
    // Lightweight cleanup to avoid unbounded map growth.
    if (this.counters.size < 10_000) return;
    for (const [key, value] of this.counters.entries()) {
      if (value.resetAt <= now) this.counters.delete(key);
    }
  }
}
