#!/usr/bin/env bash
set -euo pipefail

API_DIR="$(pwd)/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

if [ ! -f "$SCHEMA" ]; then
  echo "ERROR: schema.prisma yok: $SCHEMA"
  exit 1
fi

echo "==> Fix: remove enum CommissionStatus, use String status"

python3 - <<'PY'
import re, pathlib

p = pathlib.Path("apps/api/prisma/schema.prisma")
s = p.read_text(encoding="utf-8")

# 1) Remove enum block if exists
s2 = re.sub(r"\n?enum\s+CommissionStatus\s*\{[\s\S]*?\}\n", "\n", s, flags=re.MULTILINE)

# 2) Ensure CommissionLedger model exists and uses String status
if "model CommissionLedger" in s2:
    # Replace status field line if enum version exists
    s2 = re.sub(
        r"status\s+CommissionStatus\s+@default\(PENDING\)",
        r'status           String   @default("PENDING")',
        s2
    )
    # If status line exists but different, force it (best effort)
    s2 = re.sub(
        r"status\s+CommissionStatus\b.*",
        r'status           String   @default("PENDING")',
        s2
    )
else:
    s2 = s2.rstrip() + """

model CommissionLedger {
  id               String   @id @default(cuid())
  dealId           String   @unique
  agentId          String
  grossAmount      Int
  commissionRate   Int
  commissionAmount Int
  status           String   @default("PENDING")
  createdAt        DateTime @default(now())
}
"""

p.write_text(s2, encoding="utf-8")
print("OK: schema patched")
PY

cd "$API_DIR"

echo "==> Prisma migrate"
pnpm prisma migrate dev --name day4_no_enum --skip-generate
pnpm prisma generate

echo "==> DONE"
