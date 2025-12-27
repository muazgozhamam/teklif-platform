#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/wizard/page.tsx"
if [[ -f "apps/dashboard/src/app/wizard/page.tsx" ]]; then
  FILE="apps/dashboard/src/app/wizard/page.tsx"
fi

echo "==> Patch: $FILE (answer payload: answer)"

python3 - <<'PY' "$FILE"
from pathlib import Path
import re, sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# answerQuestion body içindeki JSON.stringify(...) alanlarını normalize et
# hedef: { key, answer, value, field } (answer şart)
txt = re.sub(
    r"body:\s*JSON\.stringify\(\{[^}]*\}\)",
    "body: JSON.stringify({ key, answer: value, value, field: key })",
    txt
)

# eğer yukarıdaki agresif replacement fazla riskliyse, spesifik replace de yapalım:
txt = txt.replace("JSON.stringify({ key, value, field: key })", "JSON.stringify({ key, answer: value, value, field: key })")
txt = txt.replace("JSON.stringify({ key: field, value, field })", "JSON.stringify({ key: field, answer: value, value, field })")

p.write_text(txt, encoding="utf-8")
print("✅ patched:", p)
PY

echo
echo "✅ DONE."
echo "Dashboard restart şart:"
echo "  (dashboard terminalinde) CTRL+C"
echo "  cd ~/Desktop/teklif-platform/apps/dashboard && pnpm dev"
echo
echo "Sonra wizard:"
echo "  http://localhost:3000/wizard (veya terminalde yazan port)"
