# Observability + Alerting (Phase 8.5)

## Scope (v1)
- In-process request metrics collector
- Health metrics endpoint
- Baseline alert thresholds/runbook

## Endpoint
- `GET /health/metrics`

Example payload (shape):
```json
{
  "startedAt": "...",
  "requestsTotal": 123,
  "errorsTotal": 2,
  "errorRatePct": 1.626,
  "statusClassCounts": { "2xx": 110, "4xx": 11, "5xx": 2 },
  "latencyMs": { "p50": 12.3, "p95": 87.1, "max": 204.5 },
  "topPaths": [{ "path": "/health", "count": 50 }],
  "sampleSize": 123
}
```

## Logging
- Optional structured request log stream:
  - `OBS_REQUEST_LOG_ENABLED=1`
- Default is disabled (`0`) to avoid noisy local logs.

## Suggested Alerts (initial)
- Error rate warning: `errorRatePct > 2%` for 5m
- Error rate critical: `errorRatePct > 5%` for 5m
- Latency warning: `latencyMs.p95 > 800ms` for 10m
- Latency critical: `latencyMs.p95 > 1500ms` for 10m

## Verification
- `scripts/diag/diag-observability.sh`

## Notes
- v1 is process-local (no external metrics backend).
- For multi-instance production, ship metrics/logs to centralized backend (Prometheus/OTEL/ELK).
