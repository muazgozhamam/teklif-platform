# Common Commands

## Workspace root
```bash
pnpm dev
pnpm build
```

## Git / Release flow (memory shortcut)
```bash
# stage icin
git checkout develop
git pull origin develop
# degisiklik + commit + push
git push origin develop

# prod icin
git checkout main
git pull origin main
git push origin main
```

## Dashboard (`apps/dashboard`)
```bash
pnpm --filter dashboard dev
pnpm --filter dashboard build
pnpm --filter dashboard lint
```

## API (`apps/api`)
```bash
pnpm --filter api build
pnpm --filter api start:dev
pnpm --filter api test
```

## Prisma (API)
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform/apps/api
pnpm exec prisma generate
pnpm exec prisma migrate dev
pnpm exec prisma db push
pnpm exec prisma db execute --file prisma/migrations/<migration>/migration.sql
```

## Seed / bootstrap (API)
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform/apps/api
pnpm exec ts-node --transpile-only scripts/bootstrap-users.ts
pnpm exec ts-node --transpile-only scripts/seed-listings-taxonomy.ts
```

## Env-safe API helpers
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform/apps/api
./scripts/start-dev-with-env.sh
./scripts/build-with-env.sh
./scripts/migrate-dev-with-env.sh
./scripts/db-push-with-env.sh
```

## Smoke examples (stage)
```bash
curl -i https://api-stage-44dd.up.railway.app/health
curl -sS "https://api-stage-44dd.up.railway.app/public/listings/categories/leaves"
curl -sS "https://api-stage-44dd.up.railway.app/public/listings/locations/cities"
curl -i https://stage.satdedi.com
```

## Post-push quick checklist
1. Push sonrasi target branch dogru mu (`develop`/`main`) kontrol et.
2. API health 200 donuyor mu kontrol et.
3. Kritik ekran smoke:
   - `/admin`
   - `/admin/applications`
   - `/admin/commission`

## Ops scripts (root)
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
APP_DOMAIN=app.satdedi.com API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-monitoring-baseline.sh
APP_DOMAIN=app.satdedi.com API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-incident-drill.sh
APP_DOMAIN=satdedi.com API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-post-go-live-smoke.sh
```
