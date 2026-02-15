#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# If copyText already exists, do nothing (idempotent)
if re.search(r"\basync function\s+copyText\s*\(", orig):
    raise SystemExit("✅ copyText helper already exists (no change).")

helper = r"""

async function copyText(s: string) {
  const text = String(s || '');
  if (!text) return;
  try {
    await navigator.clipboard.writeText(text);
    return;
  } catch {
    // fallback
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
    } catch {}
  }
}

"""

# Insert after cx(...) helper (best stable anchor)
m = re.search(r"function\s+cx\s*\([^\)]*\)\s*\{[\s\S]*?\n\}", orig)
if not m:
    raise SystemExit("❌ Anchor not found: function cx(...) {...}")

new = orig[:m.end()] + helper + orig[m.end():]

bak = p.with_suffix(p.suffix + ".add-copytext.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Added top-level copyText(s: string) helper")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
