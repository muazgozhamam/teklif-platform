#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"

python3 - <<'PY'
from pathlib import Path
import re, sys

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# Replace ONLY the explicit `: any` that causes the eslint error
# We do NOT touch other logic.
new = re.sub(
    r":\s*any(\b)",
    ": unknown\\1",
    orig,
    count=1
)

if new == orig:
    raise SystemExit("❌ No changes applied (pattern not found).")

bak = p.with_suffix(p.suffix + ".noany.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Replaced explicit `any` with `unknown`")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> ESLint re-check"
pnpm -C apps/dashboard exec eslint "app/consultant/inbox/page.tsx" 2>&1 | sed -n '1,120p'
echo "✅ Done."
