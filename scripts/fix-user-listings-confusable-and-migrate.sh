#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "SCHEMA=$SCHEMA"

if [ ! -f "$SCHEMA" ]; then
  echo "❌ schema not found: $SCHEMA"
  exit 1
fi

ts="$(date +%Y%m%d-%H%M%S)"
cp "$SCHEMA" "$SCHEMA.bak.$ts"
echo "✅ Backup: $SCHEMA.bak.$ts"

python3 - <<'PY'
from pathlib import Path
import re

schema_path = Path(__file__).resolve()  # dummy for safety
# real path passed via env-like replace not needed; use fixed location from bash by reading file directly
p = Path(r"""'"$SCHEMA"'"".strip("'"))
# The above trick won't work inside single-quoted heredoc; so re-locate via cwd:
# We'll instead read via relative known path: apps/api/prisma/schema.prisma
p = Path("apps/api/prisma/schema.prisma").resolve()

txt = p.read_text(encoding="utf-8", errors="replace")

m = re.search(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt)
if not m:
  raise SystemExit("❌ model User block not found")

block = m.group(0)
lines = block.splitlines(True)

kept = 0
new_lines = []
removed = 0

for line in lines:
  # Only operate inside the User model block: drop duplicate "Listing[]" typed lines.
  if "Listing[]" in line:
    if kept == 0:
      kept = 1
      new_lines.append(line)
    else:
      removed += 1
      # drop it
      continue
  else:
    new_lines.append(line)

if removed == 0:
  print("ℹ️ No duplicate Listing[] lines found inside User model (but Prisma still complained).")
  # Still write back normalized content to reduce invisibles
else:
  print(f"✅ Removed {removed} duplicate line(s) containing 'Listing[]' inside User model.")

new_block = "".join(new_lines)

# Replace the block
txt2 = txt[:m.start()] + new_block + txt[m.end():]

# Normalize: remove BOM/zero-width, enforce LF, trim trailing spaces
txt2 = txt2.replace("\ufeff", "").replace("\u200b", "").replace("\u200c", "").replace("\u200d", "")
txt2 = txt2.replace("\r\n", "\n").replace("\r", "\n")
txt2 = "\n".join(l.rstrip() for l in txt2.split("\n"))
if not txt2.endswith("\n"):
  txt2 += "\n"

p.write_text(txt2, encoding="utf-8")
print("✅ schema.prisma rewritten (normalized + User Listing[] dedup)")
PY

echo
echo "==> Show User model lines containing 'Listing[]' (should be 0 or 1 line)"
cd "$ROOT"
python3 - <<'PY'
from pathlib import Path
import re
p = Path("apps/api/prisma/schema.prisma").resolve()
txt = p.read_text(encoding="utf-8", errors="replace")
m = re.search(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt)
print(m.group(0) if m else "NO USER MODEL")
PY

echo
echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma
echo "✅ prisma format OK"

echo
echo "==> prisma migrate dev (create migration for current schema)"
pnpm -s prisma migrate dev --schema prisma/schema.prisma --name add_listings_sync || \
  echo "⚠️ migrate dev failed (check output above). If it asks for reset, run: pnpm -s prisma migrate reset --force"

echo
echo "==> prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma

echo
echo "==> build"
pnpm -s build

echo
echo "✅ DONE"
echo "Next:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
