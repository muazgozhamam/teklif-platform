#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "SCHEMA=$SCHEMA"

if [ ! -f "$SCHEMA" ]; then
  echo "❌ schema.prisma not found: $SCHEMA"
  exit 1
fi

cp "$SCHEMA" "$SCHEMA.bak.$(date +%Y%m%d-%H%M%S)"
echo "✅ Backup alındı"

SCHEMA="$SCHEMA" python3 - <<'PY'
from pathlib import Path
import os, re, unicodedata

schema = Path(os.environ["SCHEMA"]).resolve()
txt = schema.read_text(encoding="utf-8", errors="replace")

# Normalize file-level invisibles first
txt = txt.replace("\ufeff","").replace("\u200b","").replace("\u200c","").replace("\u200d","")
txt = txt.replace("\r\n","\n").replace("\r","\n")

m = re.search(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt)
if not m:
    raise SystemExit("❌ model User bulunamadı")

block = m.group(0)
lines = block.splitlines(True)

def norm_field_name(line: str) -> str:
    # try to extract leading field identifier: "  listings Listing[]"
    s = line.strip()
    if not s or s.startswith(("//", "#")):
        return ""
    # first token is field name
    name = s.split()[0]
    # normalize confusables
    name = unicodedata.normalize("NFKC", name)
    return name

new_lines = []
removed = 0

# Remove ANY field whose normalized name equals "listings"
for line in lines:
    if norm_field_name(line) == "listings":
        removed += 1
        continue
    new_lines.append(line)

# Insert canonical listings exactly once before closing "}"
insert = "  listings Listing[]\n"
for i in range(len(new_lines)-1, -1, -1):
    if re.match(r'^\s*\}\s*$', new_lines[i]):
        new_lines.insert(i, insert)
        break
else:
    raise SystemExit("❌ model User kapanış '}' bulunamadı")

new_block = "".join(new_lines)
txt2 = txt[:m.start()] + new_block + txt[m.end():]

# Final normalize (trim trailing spaces)
txt2 = "\n".join(l.rstrip() for l in txt2.split("\n")) + "\n"
schema.write_text(txt2, encoding="utf-8")

print(f"✅ User.listings normalize-dedup OK. Kaldırılan satır sayısı: {removed}")

# Show User block lines that normalize to listings
m2 = re.search(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt2)
ub = m2.group(0)
print("---- User block (lines containing 'list') ----")
for ln in ub.splitlines():
    if "list" in ln.lower():
        print(ln)
PY

echo
echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma

echo
echo "==> prisma migrate dev (create/apply new migration for current schema)"
pnpm -s prisma migrate dev --schema prisma/schema.prisma --name sync_schema

echo
echo "==> prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma

echo
echo "==> build"
pnpm -s build

echo
echo "✅ DONE: user.listings fixed + format + migrate + generate + build"
