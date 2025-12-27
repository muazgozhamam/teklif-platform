#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"
if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE yok"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
p = Path("apps/api/src/leads/leads.service.ts")
s = p.read_text(encoding="utf-8")

# en basit: status: 'NEW' -> status: 'OPEN'
s2 = s.replace("status: 'NEW'", "status: 'OPEN'").replace('status: "NEW"', 'status: "OPEN"')

if s2 == s:
  raise SystemExit("ERROR: leads.service.ts içinde status: 'NEW' bulunamadı. Dosyada farklı yazılmış olabilir.")
p.write_text(s2, encoding="utf-8")
print("OK: Replaced Deal status NEW -> OPEN")
PY

echo "==> Done. Şimdi API build/test:"
cd apps/api
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build
