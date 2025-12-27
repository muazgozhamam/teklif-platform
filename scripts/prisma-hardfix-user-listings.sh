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

# normalize file-level newlines & common invisibles
txt = txt.replace("\r\n","\n").replace("\r","\n")
txt = txt.replace("\ufeff","").replace("\u200b","").replace("\u200c","").replace("\u200d","").replace("\u2060","")

# count model User blocks
user_blocks = list(re.finditer(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt))
print(f"model User blocks found: {len(user_blocks)}")
if len(user_blocks) != 1:
    # Still proceed, but warn loudly
    print("⚠️ WARNING: model User count != 1. Prisma bu yüzden de çakışıyor olabilir.")

def strip_controls_and_format(s: str) -> str:
    out = []
    for ch in s:
        cat = unicodedata.category(ch)  # e.g. 'Cf', 'Cc'
        if cat in ("Cf","Cc"):
            continue
        out.append(ch)
    return "".join(out)

def norm_name(name: str) -> str:
    name = unicodedata.normalize("NFKC", name)
    name = strip_controls_and_format(name)
    name = name.strip()
    return name

def field_name_from_line(line: str) -> str:
    s = line.strip()
    if not s or s.startswith("//"):
        return ""
    parts = s.split()
    if not parts:
        return ""
    return parts[0]

# If no User block, exit
if not user_blocks:
    raise SystemExit("❌ model User bulunamadı")

m = user_blocks[0]
block = m.group(0)
lines = block.splitlines(True)

# Diagnose: show lines whose normalized field name becomes "listings"
sus = []
for idx, line in enumerate(lines, 1):
    raw = field_name_from_line(line)
    if not raw:
        continue
    nn = norm_name(raw)
    if nn == "listings":
        sus.append((idx, line, raw))

print(f"User block: fields normalizing to 'listings': {len(sus)}")
for idx, line, raw in sus:
    # print codepoints for raw name
    cps = " ".join(f"U+{ord(c):04X}" for c in raw)
    print(f"  line#{idx}: rawName={raw!r}  codepoints=[{cps}]  fullLine={line.rstrip()!r}")

# Hard-fix: remove ALL lines where normalized field name == listings
new_lines = []
removed = 0
for line in lines:
    raw = field_name_from_line(line)
    if raw and norm_name(raw) == "listings":
        removed += 1
        continue
    new_lines.append(line)

# Ensure exactly one canonical line inserted before closing brace
insert = "  listings Listing[]\n"
for i in range(len(new_lines)-1, -1, -1):
    if re.match(r'^\s*\}\s*$', new_lines[i]):
        new_lines.insert(i, insert)
        break
else:
    raise SystemExit("❌ model User kapanış '}' bulunamadı")

new_block = "".join(new_lines)
txt2 = txt[:m.start()] + new_block + txt[m.end():]

# final normalize: trim trailing spaces
txt2 = "\n".join(l.rstrip() for l in txt2.split("\n")) + "\n"
schema.write_text(txt2, encoding="utf-8")

print(f"✅ Rewritten schema.prisma. Removed listings-like fields: {removed}")

# Post-check: count literal substring occurrences (best-effort)
print(f"Post-check: txt occurrences of 'listings': {txt2.count('listings')}")
PY

echo
echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma

echo "✅ prisma format OK"
