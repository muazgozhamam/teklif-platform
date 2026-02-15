import { AdminJobsService } from './admin-jobs.service';

const BackgroundJobStatus = {
  PENDING: 'PENDING',
  RUNNING: 'RUNNING',
  SUCCEEDED: 'SUCCEEDED',
  FAILED: 'FAILED',
} as const;
type BackgroundJobStatusValue = (typeof BackgroundJobStatus)[keyof typeof BackgroundJobStatus];

type RunRow = {
  id: string;
  jobName: string;
  idempotencyKey: string;
  status: BackgroundJobStatusValue;
  attempts: number;
  maxAttempts: number;
  payload: any;
  resultJson: any;
  lastError: string | null;
  startedAt: Date | null;
  finishedAt: Date | null;
  nextRetryAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

const JOB_NAME = 'ALLOCATION_INTEGRITY_CHECK_V1';

function buildPrisma(initial?: Partial<RunRow>) {
  let row: RunRow | null = initial
    ? ({
        id: 'run_1',
        jobName: JOB_NAME,
        idempotencyKey: 'k1',
        status: BackgroundJobStatus.PENDING,
        attempts: 0,
        maxAttempts: 3,
        payload: { snapshotId: 'snap_1' },
        resultJson: null,
        lastError: null,
        startedAt: null,
        finishedAt: null,
        nextRetryAt: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        ...initial,
      } as RunRow)
    : null;

  const prisma: any = {
    backgroundJobRun: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (!row) return null;
        if (where?.id) return where.id === row.id ? row : null;
        if (where?.jobName_idempotencyKey) {
          const key = where.jobName_idempotencyKey;
          return key.jobName === row.jobName && key.idempotencyKey === row.idempotencyKey ? row : null;
        }
        return null;
      }),
      create: jest.fn(async ({ data }: any) => {
        row = {
          id: 'run_1',
          jobName: data.jobName,
          idempotencyKey: data.idempotencyKey,
          status: data.status ?? BackgroundJobStatus.PENDING,
          attempts: data.attempts ?? 0,
          maxAttempts: data.maxAttempts ?? 3,
          payload: data.payload ?? null,
          resultJson: null,
          lastError: null,
          startedAt: null,
          finishedAt: null,
          nextRetryAt: null,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        return row;
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        if (!row || where?.id !== row.id) return { count: 0 };
        const allowed = where?.status?.in ?? [];
        if (!allowed.includes(row.status)) return { count: 0 };
        row = { ...row, ...data, updatedAt: new Date() };
        return { count: 1 };
      }),
      update: jest.fn(async ({ where, data }: any) => {
        if (!row || where?.id !== row.id) throw new Error('not found');
        row = { ...row, ...data, updatedAt: new Date() };
        return row;
      }),
      findMany: jest.fn(async () => (row ? [row] : [])),
      count: jest.fn(async () => (row ? 1 : 0)),
    },
  };

  return { prisma, getRow: () => row };
}

describe('AdminJobsService', () => {
  it('returns succeeded run as reused without re-execution', async () => {
    const { prisma } = buildPrisma({ status: BackgroundJobStatus.SUCCEEDED, resultJson: { ok: true } });
    const allocations: any = { validateSnapshotIntegrity: jest.fn() };
    const service = new AdminJobsService(prisma, allocations);

    const out = await service.runAllocationIntegrityJob({ snapshotId: 'snap_1', idempotencyKey: 'k1' });

    expect(out.reused).toBe(true);
    expect(out.run.status).toBe(BackgroundJobStatus.SUCCEEDED);
    expect(allocations.validateSnapshotIntegrity).not.toHaveBeenCalled();
  });

  it('creates and executes job successfully', async () => {
    const { prisma } = buildPrisma();
    // force no existing row by changing key in request
    const allocations: any = {
      validateSnapshotIntegrity: jest.fn().mockResolvedValue({ ok: true, snapshotId: 'snap_2' }),
    };
    const service = new AdminJobsService(prisma, allocations);

    const out = await service.runAllocationIntegrityJob({ snapshotId: 'snap_2', idempotencyKey: 'k2' });

    expect(out.reused).toBe(false);
    expect(out.run.status).toBe(BackgroundJobStatus.SUCCEEDED);
    expect(out.run.attempts).toBe(1);
    expect(allocations.validateSnapshotIntegrity).toHaveBeenCalledTimes(1);
  });

  it('retries once then succeeds', async () => {
    const { prisma } = buildPrisma();
    const allocations: any = {
      validateSnapshotIntegrity: jest
        .fn()
        .mockRejectedValueOnce(new Error('boom'))
        .mockResolvedValueOnce({ ok: true, snapshotId: 'snap_3' }),
    };
    const service = new AdminJobsService(prisma, allocations);

    const out = await service.runAllocationIntegrityJob({ snapshotId: 'snap_3', idempotencyKey: 'k3' });

    expect(out.run.status).toBe(BackgroundJobStatus.SUCCEEDED);
    expect(out.run.attempts).toBe(2);
    expect(allocations.validateSnapshotIntegrity).toHaveBeenCalledTimes(2);
  });
});
