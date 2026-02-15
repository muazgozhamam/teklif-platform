# Background Jobs + Idempotency (Phase 7.4)

## Scope (v1)
A minimal, deterministic job-runner foundation for admin-triggered jobs.

## Model
- `BackgroundJobRun`
  - Unique key: `(jobName, idempotencyKey)`
  - Status: `PENDING | RUNNING | SUCCEEDED | FAILED`
  - Retry fields: `attempts`, `maxAttempts`, `nextRetryAt`, `lastError`

## Endpoint
- `POST /admin/jobs/allocation-integrity`
  - body: `{ snapshotId, idempotencyKey? }`
  - behavior:
    - same `jobName + idempotencyKey` is reused (idempotent)
    - retry policy applied on transient failure
- `GET /admin/jobs/runs?take&skip&jobName&status`

## Retry Policy
- `maxAttempts = 3`
- exponential next retry marker: `BACKGROUND_JOB_RETRY_BASE_MS * 2^(attempt-1)`
- v1 executes attempts inline (synchronous) to keep behavior deterministic.

## Validation
- `apps/api/src/admin/jobs/admin-jobs.service.spec.ts`
- `scripts/smoke-background-jobs.sh`
