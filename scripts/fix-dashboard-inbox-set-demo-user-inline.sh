#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

needle = "onClick={() => setDemoUser('consultant_seed_1')}"
replacement = (
    "onClick={() => { "
    "try { window.localStorage.setItem('x-user-id','consultant_seed_1'); } catch {} "
    "try { window.location.reload(); } catch {} "
    "}}"
)

new = orig.replace(needle, replacement, 1)

if new == orig:
    raise SystemExit("❌ Pattern not found: setDemoUser('consultant_seed_1')")

bak = p.with_suffix(p.suffix + ".setdemouser-inline.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Inlined setDemoUser(consultant_seed_1) into onClick (localStorage + reload)")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
