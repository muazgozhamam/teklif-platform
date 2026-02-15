#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# Replace the first occurrence of onClick={() => load()} with a safe reload
new = orig.replace(
    "onClick={() => load()}",
    "onClick={() => { try { window.location.reload(); } catch {} }}",
    1
)

if new == orig:
    raise SystemExit("❌ Pattern not found: `onClick={() => load()}`")

bak = p.with_suffix(p.suffix + ".refresh-noload.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Replaced Refresh button load() with window.location.reload()")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
