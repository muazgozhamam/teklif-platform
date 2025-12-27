#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"
CTRL="$API/src/deals/deals.controller.ts"

[[ -f "$CTRL" ]] || { echo "ERROR: controller not found: $CTRL"; exit 1; }

echo "==> 0) Backup controller"
TS="$(date +%Y%m%d-%H%M%S)"
cp "$CTRL" "$CTRL.bak.$TS"
echo "Backup: $CTRL.bak.$TS"
echo

echo "==> 1) Patch this.dealsService -> this.deals (only in getById line)"
python3 - "$CTRL" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# Replace only the specific pattern; keep it tight.
new = re.sub(r'\bthis\.dealsService\.getById\b', 'this.deals.getById', txt)

if new == txt:
    print("No change applied (pattern not found).")
else:
    p.write_text(new, encoding="utf-8")
    print("PATCHED controller: this.dealsService.getById -> this.deals.getById")
PY

echo
echo "==> 2) Build"
cd "$API"
pnpm -s build

echo
echo "✅ DONE"
echo "Restart API, then test:"
echo "  curl -i \"http://localhost:3001/deals/cmjmdz7rj0001grmfeyx69qie\""
