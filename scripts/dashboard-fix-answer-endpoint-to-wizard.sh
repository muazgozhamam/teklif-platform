#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/wizard/page.tsx"
if [[ -f "apps/dashboard/src/app/wizard/page.tsx" ]]; then
  FILE="apps/dashboard/src/app/wizard/page.tsx"
fi

echo "==> Patch: $FILE (POST /leads/:id/wizard/answer)"

python3 - <<'PY' "$FILE"
from pathlib import Path
import sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# /leads/${leadId}/answer -> /leads/${leadId}/wizard/answer
txt2 = txt.replace("`/leads/${leadId}/answer`", "`/leads/${leadId}/wizard/answer`")
txt2 = txt2.replace(f"/leads/${{leadId}}/answer", f"/leads/${{leadId}}/wizard/answer")

# bazen düz string kullanılmış olabilir
txt2 = txt2.replace("/leads/${leadId}/answer", "/leads/${leadId}/wizard/answer")
txt2 = txt2.replace("/leads/${leadId}/answer", "/leads/${leadId}/wizard/answer")

p.write_text(txt2, encoding="utf-8")
print("✅ patched:", p)
PY

echo
echo "✅ DONE."
echo "Dashboard restart şart:"
echo "  (dashboard terminalinde) CTRL+C"
echo "  cd ~/Desktop/teklif-platform/apps/dashboard && pnpm dev"
echo
echo "Sonra:"
echo "  http://localhost:3000/wizard (veya terminalde yazan port)"
