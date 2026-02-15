#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# If a top-level helper already exists, do nothing
if re.search(r"(?m)^async function readJsonOrText\(", orig):
    print("ℹ️ readJsonOrText already exists at top-level. No changes.")
    raise SystemExit(0)

# Insert helper just before function cx(...) (safe, early in file)
marker = re.search(r"(?m)^function cx\(", orig)
if not marker:
    raise SystemExit("❌ Pattern mismatch: could not find `function cx(` marker.")

helper = """
async function readJsonOrText(r: Response) {
  const raw = await r.text().catch(() => '');
  try {
    return { json: raw ? JSON.parse(raw) : null, raw };
  } catch {
    return { json: null, raw };
  }
}

"""

new = orig[:marker.start()] + helper + orig[marker.start():]

bak = p.with_suffix(p.suffix + ".readjson.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Added top-level readJsonOrText helper")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
