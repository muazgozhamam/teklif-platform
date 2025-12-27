#!/usr/bin/env bash
set -e

API_DIR="$(pwd)/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "SCHEMA=$SCHEMA"
cp "$SCHEMA" "$SCHEMA.bak.$(date +%Y%m%d-%H%M%S)"
echo "✅ Backup alındı"

python3 <<'PY'
from pathlib import Path
import re, unicodedata

p = Path("apps/api/prisma/schema.prisma").resolve()
txt = p.read_text(encoding="utf-8", errors="replace")

m = re.search(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt)
if not m:
    raise SystemExit("❌ model User bulunamadı")

block = m.group(0)
lines = block.splitlines(True)

def norm_ident(s: str) -> str:
    # Remove Unicode "format" characters (Cf) and zero-width etc.
    out = []
    for ch in s:
        cat = unicodedata.category(ch)
        if cat == "Cf":
            continue
        out.append(ch)
    return "".join(out)

# Collect and dedup Listing[] fields by normalized identifier
seen = set()
removed = 0
new_lines = []

field_re = re.compile(r'^(\s*)(\S+)(\s+)(Listing\s*\[\s*\])(\s*.*)$')

for line in lines:
    mm = field_re.match(line)
    if not mm:
        new_lines.append(line)
        continue

    indent, name_raw, midspace, listing_part, tail = mm.groups()

    # Only dedup fields whose type is Listing[]
    if "Listing" not in listing_part:
        new_lines.append(line)
        continue

    name_norm = norm_ident(name_raw)

    key = (name_norm, "Listing[]")
    if key in seen:
        removed += 1
        continue

    seen.add(key)
    # rewrite identifier to normalized (drop hidden chars) to avoid reappearing
    fixed = f"{indent}{name_norm}{midspace}Listing[]{tail}"
    new_lines.append(fixed)

new_block = "".join(new_lines)
txt2 = txt[:m.start()] + new_block + txt[m.end():]

# normalize file
txt2 = txt2.replace("\ufeff","").replace("\u200b","").replace("\r\n","\n").replace("\r","\n")
txt2 = "\n".join(l.rstrip() for l in txt2.split("\n")) + "\n"

p.write_text(txt2, encoding="utf-8")

print(f"✅ Confusable dedup tamam. Silinen Listing[] satırı: {removed}")
# Quick sanity: print User block lines that mention Listing
u = re.search(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt2)
if u:
    for i, ln in enumerate(u.group(0).splitlines(), 1):
        if "Listing" in ln:
            print("USER:", ln)
PY

echo
echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma
echo "✅ prisma format OK"
