#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# Replace the first lines of getBadgeKind to safely access properties from `unknown`.
pat = r"""function\s+getBadgeKind\(d:\s*unknown\):\s*'linked'\s*\|\s*'ready'\s*\|\s*'claimed'\s*\|\s*'open'\s*\{\s*
\s*const\s+status\s*=\s*String\(d\?\.\s*status\s*\|\|\s*''\)\.toUpperCase\(\)\.trim\(\);\s*
\s*const\s+hasListing\s*=\s*Boolean\(d\?\.\s*listingId\s*\|\|\s*d\?\.\s*linkedListingId\);\s*
\s*const\s+consultantId\s*=\s*String\(d\?\.\s*consultantId\s*\|\|\s*''\)\.trim\(\);\s*
"""
m = re.search(pat, orig, flags=re.S | re.X)
if not m:
    raise SystemExit("❌ Pattern not found: getBadgeKind() header+first lines (unknown + d?.status/listingId/consultantId).")

replacement = (
    "function getBadgeKind(d: unknown): 'linked' | 'ready' | 'claimed' | 'open' {\n"
    "  const x = (d as any) || {};\n"
    "  const status = String(x.status || '').toUpperCase().trim();\n"
    "  const hasListing = Boolean(x.listingId || x.linkedListingId);\n"
    "  const consultantId = String(x.consultantId || '').trim();\n"
)

new = orig[:m.start()] + replacement + orig[m.end():]

bak = p.with_suffix(p.suffix + ".badgekind-unknown.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Patched getBadgeKind(): safe property access from `unknown` via (d as any)")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
