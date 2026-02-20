# Services / Deploy Targets

## Detected Config Files
- `railway.json`: Unknown (not found)
- `render.yaml`: Unknown (not found)
- `vercel.json`: Unknown (not found)
- `Dockerfile`: Unknown (not found)
- `docker-compose.db.yml`: found at `/Users/muazgozhamam/Desktop/teklif-platform/docker-compose.db.yml`

## Git Hosting
- GitHub remote: `git@github.com:muazgozhamam/teklif-platform.git`

## Railway (inferred from docs/scripts, not from railway.json)
- Stage API: `https://api-stage-44dd.up.railway.app`
- Stage Dashboard: `https://stage.satdedi.com`
- Prod API: `https://api.satdedi.com`
- Prod Dashboard: `https://app.satdedi.com`
- Railway project name: `cozy-tranquility` (source: `dev-notes.md`, not from platform config file)
- Branch mapping (inferred from `dev-notes.md`):
  - `develop` -> stage
  - `main` -> production
- Evidence:
  - `/Users/muazgozhamam/Desktop/teklif-platform/dev-notes.md`
  - `/Users/muazgozhamam/Desktop/teklif-platform/SATDEDI_OPS_HANDOVER.md`
  - `/Users/muazgozhamam/Desktop/teklif-platform/scripts/ops/satdedi-*.sh`

## Where service URLs are wired in code
- Dashboard API base resolution:
  - `/Users/muazgozhamam/Desktop/teklif-platform/apps/dashboard/lib/api.ts`
  - `/Users/muazgozhamam/Desktop/teklif-platform/apps/dashboard/lib/proxy.ts`
- Admin app proxy base:
  - `/Users/muazgozhamam/Desktop/teklif-platform/apps/admin/src/lib/proxy.ts`
- OAuth allowed redirects include stage/prod dashboard login:
  - `/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/auth/auth.service.ts`

## Notes
- Railway service names/project IDs are Unknown (not codified in repo config files).

## Practical Deploy Reminder
1. Stage release icin `develop` branch'ine push et.
2. Railway stage deploy tamamlaninca health kontrolu yap:
   - `https://api-stage-44dd.up.railway.app/health`
3. Dashboard stage smoke kontrolu:
   - `https://stage.satdedi.com`
4. Prod release gerekiyorsa ayni akis `main` branch + prod URL'ler ile uygulanir.
