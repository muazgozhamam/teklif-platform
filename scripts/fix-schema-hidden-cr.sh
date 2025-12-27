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
import os

p = Path(os.environ["SCHEMA"])
b = p.read_bytes()

needle = b"listings"
count = b.count(needle)

print(f"==> RAW bytes: size={len(b)} bytes")
print(f"==> Occurrences of 'listings' in bytes: {count}")

# listings geçen yerlerin etrafından 80 byte göster (hex + printable)
idxs = []
i = 0
while True:
    j = b.find(needle, i)
    if j == -1: break
    idxs.append(j)
    i = j + 1

def dump_window(pos, w=80):
    s = max(0, pos-20)
    e = min(len(b), pos+w)
    chunk = b[s:e]
    # printable
    printable = ''.join(chr(x) if 32 <= x <= 126 else '.' for x in chunk)
    # hex
    hx = ' '.join(f"{x:02x}" for x in chunk)
    return s, e, printable, hx

for k, pos in enumerate(idxs[:10], 1):
    s,e,pr,hx = dump_window(pos)
    print(f"\n--- match#{k} at byte {pos} (window {s}:{e}) ---")
    print(pr)
    print(hx)

# Normalize:
# - Convert CRLF/CR to LF
# - Remove BOM and zero-width spaces
txt = b.decode("utf-8", errors="replace")
txt2 = txt.replace("\r\n", "\n").replace("\r", "\n")
txt2 = txt2.replace("\ufeff", "").replace("\u200b", "")

# Also trim trailing spaces on each line (safe for prisma)
txt2 = "\n".join(line.rstrip() for line in txt2.split("\n")) + ("\n" if not txt2.endswith("\n") else "")

p.write_text(txt2, encoding="utf-8")
print("\n✅ Wrote normalized UTF-8 LF file (CR removed, invisible chars removed).")
print(f"Now text occurrences of 'listings': {txt2.count('listings')}")
PY

echo
echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma
echo "✅ prisma format OK"
