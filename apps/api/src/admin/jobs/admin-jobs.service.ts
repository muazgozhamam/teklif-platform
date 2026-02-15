import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AllocationsService } from '../../allocations/allocations.service';
import { PrismaService } from '../../prisma/prisma.service';

type RunJobInput = {
  snapshotId: string;
  idempotencyKey?: string;
};

type ListRunsQuery = {
  take?: number;
  skip?: number;
  jobName?: string;
  status?: string;
};

const JOB_NAME_ALLOCATION_INTEGRITY = 'ALLOCATION_INTEGRITY_CHECK_V1';
const JOB_STATUS = {
  PENDING: 'PENDING',
  RUNNING: 'RUNNING',
  SUCCEEDED: 'SUCCEEDED',
  FAILED: 'FAILED',
} as const;
type JobStatus = (typeof JOB_STATUS)[keyof typeof JOB_STATUS];

@Injectable()
export class AdminJobsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly allocations: AllocationsService,
  ) {}

  private retryBaseDelayMs(): number {
    const raw = Number(process.env.BACKGROUND_JOB_RETRY_BASE_MS ?? 200);
    return Number.isFinite(raw) && raw > 0 ? Math.min(raw, 10_000) : 200;
  }

  private parseJobStatus(value?: string): JobStatus | undefined {
    const v = String(value ?? '').trim().toUpperCase();
    if (!v) return undefined;
    if (!Object.values(JOB_STATUS).includes(v as JobStatus)) return undefined;
    return v as JobStatus;
  }

  private normalizeKey(input: RunJobInput): string {
    const explicit = String(input.idempotencyKey ?? '').trim();
    if (explicit) return explicit;
    return `${JOB_NAME_ALLOCATION_INTEGRITY}:${String(input.snapshotId ?? '').trim()}`;
  }

  async listRuns(query: ListRunsQuery) {
    const take = Math.min(Math.max(Number(query.take ?? 20) || 20, 1), 100);
    const skip = Math.max(Number(query.skip ?? 0) || 0, 0);
    const jobName = String(query.jobName ?? '').trim();
    const status = this.parseJobStatus(query.status);

    const where: Prisma.BackgroundJobRunWhereInput = {};
    if (jobName) where.jobName = jobName;
    if (status) where.status = status;

    const [items, total] = await Promise.all([
      this.prisma.backgroundJobRun.findMany({
        where,
        take,
        skip,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.backgroundJobRun.count({ where }),
    ]);

    return { items, total, take, skip };
  }

  async runAllocationIntegrityJob(input: RunJobInput) {
    const snapshotId = String(input.snapshotId ?? '').trim();
    if (!snapshotId) {
      throw new Error('snapshotId is required');
    }

    const idempotencyKey = this.normalizeKey(input);
    const existing = await this.prisma.backgroundJobRun.findUnique({
      where: {
        jobName_idempotencyKey: {
          jobName: JOB_NAME_ALLOCATION_INTEGRITY,
          idempotencyKey,
        },
      },
    });

    if (existing?.status === JOB_STATUS.SUCCEEDED) {
      return { reused: true, run: existing };
    }

    if (existing?.status === JOB_STATUS.RUNNING) {
      return { reused: true, run: existing };
    }

    const run =
      existing ??
      (await this.prisma.backgroundJobRun.create({
        data: {
          jobName: JOB_NAME_ALLOCATION_INTEGRITY,
          idempotencyKey,
          maxAttempts: 3,
          payload: { snapshotId },
        },
      }));

    const finalRun = await this.executeWithRetry(run.id, snapshotId);
    return { reused: false, run: finalRun };
  }

  private async executeWithRetry(runId: string, snapshotId: string) {
    let current = await this.prisma.backgroundJobRun.findUnique({ where: { id: runId } });
    if (!current) {
      throw new Error('Job run not found');
    }

    const maxAttempts = Math.max(current.maxAttempts || 3, 1);

    for (let attempt = current.attempts + 1; attempt <= maxAttempts; attempt += 1) {
      const now = new Date();
      const lock = await this.prisma.backgroundJobRun.updateMany({
        where: {
          id: runId,
          status: { in: [JOB_STATUS.PENDING, JOB_STATUS.FAILED] },
        },
        data: {
          status: JOB_STATUS.RUNNING,
          attempts: attempt,
          startedAt: current.startedAt ?? now,
          nextRetryAt: null,
        },
      });

      if (lock.count === 0) {
        const concurrent = await this.prisma.backgroundJobRun.findUnique({ where: { id: runId } });
        if (!concurrent) throw new Error('Job run not found after lock');
        return concurrent;
      }

      try {
        const result = await this.allocations.validateSnapshotIntegrity(snapshotId);
        const succeeded = await this.prisma.backgroundJobRun.update({
          where: { id: runId },
          data: {
            status: JOB_STATUS.SUCCEEDED,
            resultJson: result,
            finishedAt: new Date(),
            lastError: null,
            nextRetryAt: null,
          },
        });
        return succeeded;
      } catch (error) {
        const message = error instanceof Error ? error.message : 'job failed';
        const shouldRetry = attempt < maxAttempts;
        const delayMs = this.retryBaseDelayMs() * Math.pow(2, attempt - 1);
        const failed = await this.prisma.backgroundJobRun.update({
          where: { id: runId },
          data: {
            status: shouldRetry ? JOB_STATUS.PENDING : JOB_STATUS.FAILED,
            finishedAt: shouldRetry ? null : new Date(),
            lastError: message,
            nextRetryAt: shouldRetry ? new Date(Date.now() + delayMs) : null,
          },
        });

        current = failed;
        if (!shouldRetry) {
          return failed;
        }
      }
    }

    const terminal = await this.prisma.backgroundJobRun.findUnique({ where: { id: runId } });
    if (!terminal) throw new Error('Job run not found at terminal state');
    return terminal;
  }
}
