# Project Memory

## Repo
- Name: `teklif-platform`
- Root: `/Users/muazgozhamam/Desktop/teklif-platform`
- Git remote: `git@github.com:muazgozhamam/teklif-platform.git`

## Monorepo Structure
- Workspace manager: `pnpm`
- Task runner: `turbo`
- Workspace file: `/Users/muazgozhamam/Desktop/teklif-platform/pnpm-workspace.yaml`
- Packages:
  - `apps/api` (NestJS + Prisma + PostgreSQL)
  - `apps/dashboard` (Next.js App Router)
  - `apps/admin` (Next.js legacy/admin app)
  - `apps/mobile` (Expo React Native)
  - `packages/shared`

## Stack
- API: NestJS 11, Prisma 7, PostgreSQL (`@prisma/adapter-pg`)
- Dashboard: Next.js 16.1.1, React 19, Tailwind 4
- Admin app: Next.js 15, React 18
- Mobile: Expo 51, React Native 0.74

## Data Layer
- Prisma schema: `/Users/muazgozhamam/Desktop/teklif-platform/apps/api/prisma/schema.prisma`
- Prisma config: `/Users/muazgozhamam/Desktop/teklif-platform/apps/api/prisma.config.ts`
- Prisma config behavior:
  - Loads env from `apps/api/.env`
  - Then tries repo root `.env`
  - Fails fast if `DATABASE_URL` is missing

## Important Areas (recently active)
- Admin CRM / Applications
- Admin Commission (hak edis)
- Admin Performance
- Listings (public + dashboard)
- Location cascader and map pin

## Scripts / Tooling Notes
- Root scripts folder is large (`/Users/muazgozhamam/Desktop/teklif-platform/scripts`), mostly one-shot patch/fix helpers.
- Operational scripts are in `/Users/muazgozhamam/Desktop/teklif-platform/scripts/ops`.
- API env-safe helper scripts in `/Users/muazgozhamam/Desktop/teklif-platform/apps/api/scripts`:
  - `start-with-env.sh`
  - `start-dev-with-env.sh`
  - `build-with-env.sh`
  - `migrate-dev-with-env.sh`
  - `db-push-with-env.sh`

## Known Public/Stage URLs (from repo docs)
- Stage dashboard: `https://stage.satdedi.com`
- Stage API: `https://api-stage-44dd.up.railway.app`
- Prod dashboard: `https://app.satdedi.com`
- Prod API: `https://api.satdedi.com`
- Source references:
  - `/Users/muazgozhamam/Desktop/teklif-platform/dev-notes.md`
  - `/Users/muazgozhamam/Desktop/teklif-platform/SATDEDI_*.md`

## Team Memory (Do Not Repeat Every Chat)
- Railway branch mapping notu mevcut:
  - `develop` -> stage
  - `main` -> production
- Bu bilgi kaynaklari:
  - `/Users/muazgozhamam/Desktop/teklif-platform/dev-notes.md:16`
  - `/Users/muazgozhamam/Desktop/teklif-platform/dev-notes.md:173`
- Yeni chat basinda bu mapping varsayimi ile ilerlenmeli; tekrar tekrar sorulmamalı.
