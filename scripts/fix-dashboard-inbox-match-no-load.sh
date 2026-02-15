#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# Replace the first occurrence of "await load();" inside matchDeal flow.
# We keep behavior: refresh UI after match, but via reload (no dependency on load()).
if "await load();" not in orig:
    raise SystemExit("❌ Pattern not found: `await load();`")

new = orig.replace(
    "      await load();",
    "      try { window.location.reload(); } catch {}",
    1
)

if new == orig:
    raise SystemExit("❌ No changes applied (unexpected).")

bak = p.with_suffix(p.suffix + ".match-noload.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Replaced `await load();` with `window.location.reload()` in matchDeal flow")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
