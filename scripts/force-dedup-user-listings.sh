#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "SCHEMA=$SCHEMA"
test -f "$SCHEMA" || { echo "❌ schema.prisma yok"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
cp "$SCHEMA" "$SCHEMA.bak.$ts"
echo "✅ Backup: $SCHEMA.bak.$ts"

python3 - <<'PY'
from pathlib import Path
import os, re

p = Path(os.environ["SCHEMA"])
txt = p.read_text(encoding="utf-8")

lines = txt.splitlines(True)

# 1) model User bloğunu bul (ilk User bloğu)
start = None
brace = 0
for i, ln in enumerate(lines):
    if start is None and re.match(r'^\s*model\s+User\s*\{', ln):
        start = i
        brace = ln.count('{') - ln.count('}')
        continue
    if start is not None:
        brace += ln.count('{') - ln.count('}')
        if brace == 0:
            end = i
            break
else:
    raise SystemExit("❌ model User bloğu bulunamadı veya kapanmıyor.")

user_block = lines[start:end+1]

# 2) listings satırlarını dedup et (normalize ederek)
seen = False
kept_line = None
found = 0
new_block = []

def norm(s: str) -> str:
    # görünmeyen karakterleri de normalize etmeye çalış
    s2 = s.replace('\u200b','').replace('\ufeff','')
    s2 = s2.replace('\r','')
    return s2.strip()

for ln in user_block:
    n = norm(ln)
    # satır "listings" ile başlıyorsa (attribute olsa da olur)
    if re.match(r'^listings\b', n):
        found += 1
        if not seen:
            seen = True
            kept_line = ln
            new_block.append(ln)
        else:
            # drop duplicate
            continue
    else:
        new_block.append(ln)

print(f"FOUND listings lines in User model: {found}")
if found >= 2:
    print("✅ Dedup applied: kept first, removed the rest.")
elif found == 1:
    print("ℹ️ Only one listings line existed; no change needed.")
else:
    print("⚠️ No listings line found inside User model. (Prisma still errors => User model might be duplicated elsewhere)")

# 3) dosyayı güncelle
new_lines = lines[:start] + new_block + lines[end+1:]
p.write_text(''.join(new_lines), encoding="utf-8")
PY

echo "==> sanity: show User listings lines (grep)"
grep -n "^[[:space:]]*listings[[:space:]]" "$SCHEMA" || true

echo "==> prisma format (should pass now)"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma

echo "✅ DONE: User.listings force-dedup + prisma format OK"
