#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"
if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE yok"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/leads.service.ts")
s = p.read_text(encoding="utf-8")

before = s

# 1) data object içinde "title," (shorthand) varsa kaldır
s = re.sub(r"\n(\s*)title\s*,\s*", r"\n\1", s)

# 2) data object içinde "title: <expr>," varsa kaldır
s = re.sub(r"\n(\s*)title\s*:\s*[^,\n]+,\s*", r"\n\1", s)

# 3) data object içinde "title: <expr>" (son eleman) varsa kaldır
s = re.sub(r"\n(\s*)title\s*:\s*[^,\n]+\s*\n", r"\n", s)

if s == before:
  raise SystemExit("ERROR: leads.service.ts içinde title alanı bulunamadı. title farklı bir yerde/formatta olabilir.")

p.write_text(s, encoding="utf-8")
print("OK: Removed Deal.title from deal.create data")
PY

echo "==> Prisma generate + build"
cd apps/api
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build

echo
echo "==> DONE. Şimdi dev server restart:"
echo "cd apps/api && pnpm start:dev"
