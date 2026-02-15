import { Injectable } from '@nestjs/common';

type RequestSample = {
  ts: number;
  method: string;
  path: string;
  status: number;
  durationMs: number;
};

@Injectable()
export class ObservabilityService {
  private readonly startedAt = new Date();
  private requestsTotal = 0;
  private errorsTotal = 0;
  private readonly byPath = new Map<string, number>();
  private readonly byStatusClass = new Map<string, number>();
  private readonly recentSamples: RequestSample[] = [];
  private readonly maxSamples = 5_000;

  record(sample: RequestSample) {
    this.requestsTotal += 1;
    if (sample.status >= 500) this.errorsTotal += 1;

    const pathCount = this.byPath.get(sample.path) ?? 0;
    this.byPath.set(sample.path, pathCount + 1);

    const statusClass = `${Math.floor(sample.status / 100)}xx`;
    const clsCount = this.byStatusClass.get(statusClass) ?? 0;
    this.byStatusClass.set(statusClass, clsCount + 1);

    this.recentSamples.push(sample);
    if (this.recentSamples.length > this.maxSamples) {
      this.recentSamples.splice(0, this.recentSamples.length - this.maxSamples);
    }
  }

  private percentile(values: number[], p: number): number {
    if (!values.length) return 0;
    const sorted = [...values].sort((a, b) => a - b);
    const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
    return Number(sorted[idx].toFixed(3));
  }

  private topPaths(limit = 10): Array<{ path: string; count: number }> {
    return [...this.byPath.entries()]
      .map(([path, count]) => ({ path, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, limit);
  }

  snapshot() {
    const durations = this.recentSamples.map((s) => s.durationMs);
    const errorRate = this.requestsTotal > 0 ? Number(((this.errorsTotal / this.requestsTotal) * 100).toFixed(3)) : 0;

    return {
      startedAt: this.startedAt.toISOString(),
      requestsTotal: this.requestsTotal,
      errorsTotal: this.errorsTotal,
      errorRatePct: errorRate,
      statusClassCounts: Object.fromEntries(this.byStatusClass.entries()),
      latencyMs: {
        p50: this.percentile(durations, 50),
        p95: this.percentile(durations, 95),
        max: durations.length ? Number(Math.max(...durations).toFixed(3)) : 0,
      },
      topPaths: this.topPaths(),
      sampleSize: durations.length,
    };
  }
}
