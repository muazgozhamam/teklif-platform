#!/usr/bin/env bash
set -euo pipefail

API_DIR="apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"
PCONFIG="$API_DIR/prisma.config.ts"
ENVFILE="$API_DIR/.env"

echo "==> 0) Preconditions"
test -f "$SCHEMA" || { echo "ERR: $SCHEMA yok"; exit 1; }
test -f "$ENVFILE" || { echo "ERR: $ENVFILE yok"; exit 1; }

echo "==> 1) Patch schema.prisma (remove datasource url)"
python3 - <<'PY'
from pathlib import Path
p = Path("apps/api/prisma/schema.prisma")
lines = p.read_text(encoding="utf-8").splitlines()

out = []
for line in lines:
    if "url" in line and "DATABASE_URL" in line:
        continue
    out.append(line)

p.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
print("OK: schema.prisma cleaned")
PY

echo "==> 2) Ensure prisma.config.ts (Prisma 7 compatible)"
cat <<'TS' > apps/api/prisma.config.ts
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  datasource: {
    url: env('DATABASE_URL'),
  },
});
TS
echo "OK: prisma.config.ts written"

echo "==> 3) Load apps/api/.env and run migrate"
cd "$API_DIR"
set -a
source ./.env
set +a

# hızlı kontrol (log için)
if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERR: DATABASE_URL env boş. apps/api/.env kontrol et."
  exit 1
fi

pnpm -s prisma migrate dev -n add_deal --schema prisma/schema.prisma

echo
echo "==> DONE"
