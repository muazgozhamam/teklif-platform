# Known Issues Log

## Current known patterns

### 0) Deploy expectation mismatch (stage/prod)
- Symptom: Kod pushlandi ama stage/prod'da degisiklik yok.
- Common cause: Yanlis branch'e push (`develop` yerine farkli branch) veya deploy tamamlanmadan kontrol.
- Check:
  - branch: `git rev-parse --abbrev-ref HEAD`
  - remote: `git remote -v`
  - stage health: `https://api-stage-44dd.up.railway.app/health`
  - stage app: `https://stage.satdedi.com`

### 1) CRM pages show `API request failed`
- Symptom: Admin CRM list/overview errors.
- Common cause: Stage DB schema drift (missing `Application*` tables/enums).
- Check:
  - API logs for Prisma `P2021` / `P2022`
  - migration state for applications tables
- Notes:
  - Fallback handling was hardened in API service recently.

### 2) Commission pages fail due missing tables
- Symptom examples:
  - `CommissionAuditEvent does not exist`
  - `CommissionPeriodLock does not exist`
- Cause: migrations not applied on stage/prod DB.
- Fix path:
  1. apply migration SQL to target DB
  2. redeploy API
  3. re-check `/admin/commission/*`

### 3) Dashboard build hangs/fails on `.next` cleanup in CI
- Historical symptom: `.next/cache` busy / rm failure.
- Current mitigation: dashboard build script uses non-fatal Node cleanup then `next build --webpack`.

### 4) Location data mismatch (district/neighborhood)
- Symptom: missing/wrong neighborhoods.
- Cause: partial/broken import or wrong dataset format.
- Check:
  - `/public/listings/locations/debug`
  - row counts city/district/neighborhood

---

## Issue template

### Issue: <short title>
- Date:
- Environment: local | stage | prod
- Affected app: api | dashboard | admin | mobile
- URL/route:
- Error message:
- Repro steps:
1. 
2. 
3. 

### Diagnostics
- API logs:
- DB check:
- Network response (status/body):

### Tried
- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

### Outcome
- Result:
- Next action:
- Owner:
