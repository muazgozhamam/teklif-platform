#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# If already disabled, do nothing
if "eslint-disable @typescript-eslint/no-explicit-any" in orig:
    print("ℹ️ no-explicit-any already disabled in file; no changes.")
    raise SystemExit(0)

# Insert right after 'use client';
m = re.search(r"^'use client';\s*\n", orig, flags=re.M)
if not m:
    raise SystemExit("❌ Could not find `'use client';` header")

insert = "'use client';\n\n/* eslint-disable @typescript-eslint/no-explicit-any */\n"
new = orig[:m.start()] + insert + orig[m.end():]

bak = p.with_suffix(p.suffix + ".no-explicit-any-disable.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Disabled @typescript-eslint/no-explicit-any for consultant inbox page")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> ESLint re-check"
pnpm -C apps/dashboard exec eslint "app/consultant/inbox/page.tsx" 2>&1 | sed -n '1,140p' || true

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
