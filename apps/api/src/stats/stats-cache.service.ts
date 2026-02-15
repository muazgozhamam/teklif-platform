import { Injectable } from '@nestjs/common';

type Entry = {
  expiresAt: number;
  value: unknown;
};

@Injectable()
export class StatsCacheService {
  private readonly store = new Map<string, Entry>();
  private readonly ttlMs: number;

  constructor() {
    const raw = Number(process.env.DASHBOARD_STATS_CACHE_TTL_MS ?? 15_000);
    this.ttlMs = Number.isFinite(raw) && raw > 0 ? Math.min(raw, 10 * 60 * 1000) : 15_000;
  }

  get<T>(key: string): T | null {
    const hit = this.store.get(key);
    if (!hit) return null;
    if (Date.now() > hit.expiresAt) {
      this.store.delete(key);
      return null;
    }
    return hit.value as T;
  }

  set(key: string, value: unknown): void {
    this.store.set(key, { value, expiresAt: Date.now() + this.ttlMs });
  }
}
