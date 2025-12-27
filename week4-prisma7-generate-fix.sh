#!/usr/bin/env bash
set -euo pipefail

API_DIR="apps/api"
cd "$API_DIR"

echo "==> 0) Load .env (DATABASE_URL)"
if [ ! -f ".env" ]; then
  echo "ERROR: apps/api/.env yok. DATABASE_URL bulunamadı."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: DATABASE_URL boş. apps/api/.env içini kontrol et."
  exit 1
fi
echo "OK: DATABASE_URL loaded"

echo
echo "==> 1) Write prisma.config.ts (Prisma 7 compatible)"
cat > prisma.config.ts <<'TS'
import { defineConfig } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  datasource: {
    url: process.env.DATABASE_URL,
  },
});
TS
echo "OK: prisma.config.ts written"

echo
echo "==> 2) Prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma

echo
echo "==> 3) Build check"
pnpm -s build

echo
echo "✅ DONE"
echo "Next: dev serveri restart et:"
echo "  cd ~/Desktop/teklif-platform/apps/api"
echo "  pnpm start:dev"
