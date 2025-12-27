#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="$ROOT/apps/api/src/listings/listings.service.ts"

echo "==> ROOT=$ROOT"
echo "==> Target: $TARGET"
[ -f "$TARGET" ] || { echo "❌ Missing: $TARGET"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8")

# 1) Ensure default feed is PUBLISHED when no explicit status provided.
# We look for something like:
# if ((filters as any)?.status) { where.status = ... } else if (!publishedFalse) { where.status = 'PUBLISHED'; }
# Since we already removed 'published' field, we want:
# if (filters.status) where.status = filters.status else where.status = 'PUBLISHED'
#
# We'll do a conservative patch inside async list(...) method by replacing a common block.

m = re.search(r"\basync\s+list\s*\(\s*filters\s*:\s*any.*?\)\s*{\s*", txt, re.S)
if not m:
    raise SystemExit("❌ Could not locate async list(filters...) signature.")

# Find first occurrence of "const where" after list start
start = m.end()
m_where = re.search(r"\bconst\s+where\s*:\s*any\s*=\s*{\s*}\s*;\s*", txt[start:], re.S)
if not m_where:
    raise SystemExit("❌ Could not find `const where: any = {};` in list().")

where_pos = start + m_where.end()

# We will inject a small, idempotent default-status block shortly after const where
inject = """
    // Default feed behavior: if caller doesn't specify status, show only PUBLISHED
    if ((filters as any)?.status) {
      where.status = (filters as any).status;
    } else {
      where.status = 'PUBLISHED';
    }
"""

# Avoid double-inject
if "Default feed behavior: if caller doesn't specify status" not in txt:
    txt = txt[:where_pos] + inject + txt[where_pos:]

# 2) Remove any leftover logic that tries to interpret `published` query param (best-effort)
txt = re.sub(r"\s*const\s+publishedRaw\s*:\s*any\s*=.*?;\s*", "\n", txt, flags=re.S)
txt = re.sub(r"\s*const\s+publishedFalse\s*=.*?;\s*", "\n", txt, flags=re.S)
txt = re.sub(r"\s*else\s+if\s*\(\s*!\s*publishedFalse\s*\)\s*{\s*where\.status\s*=\s*'PUBLISHED'\s*;\s*}\s*", "\n", txt, flags=re.S)

p.write_text(txt, encoding="utf-8")
print("✅ Patched: list() defaults to status='PUBLISHED' when status not provided (and removed published param remnants).")
PY

echo "✅ Done."
