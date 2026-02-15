#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

if "function getBadgeLabel(" in orig:
    raise SystemExit("❌ getBadgeLabel already exists (unexpected).")

# Insert right after getBadgeKind(...) function end.
# We find the definition line and then the next standalone "}" that closes it (best-effort).
m = re.search(r"function\s+getBadgeKind\s*\([\s\S]*?\n\}", orig)
if not m:
    raise SystemExit("❌ Could not locate getBadgeKind() block to insert after.")

insert_at = m.end()

helper = """

function getBadgeLabel(d: unknown): string {
  const kind = getBadgeKind(d);
  if (kind === 'linked') return 'Linked';
  if (kind === 'ready') return 'Ready';
  if (kind === 'claimed') return 'Claimed';
  if (kind === 'open') return 'Open';
  return 'Other';
}

"""

new = orig[:insert_at] + helper + orig[insert_at:]

bak = p.with_suffix(p.suffix + ".add-badgelabel.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Added getBadgeLabel() helper (top-level, based on getBadgeKind)")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
