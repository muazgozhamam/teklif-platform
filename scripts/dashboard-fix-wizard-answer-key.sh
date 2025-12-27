#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/wizard/page.tsx"
if [[ -f "apps/dashboard/src/app/wizard/page.tsx" ]]; then
  FILE="apps/dashboard/src/app/wizard/page.tsx"
fi

echo "==> Patch: $FILE (answer payload -> key)"

python3 - <<'PY' "$FILE"
from pathlib import Path
import re, sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# answerQuestion fonksiyonunu { key, value } gönderecek şekilde düzelt
pattern = r"async function answerQuestion\(\s*leadId:\s*string,\s*field:\s*string,\s*value:\s*string\s*\)\s*\{\s*return http\.req\(apiPath\(`\/leads\/\$\{leadId\}\/answer`\),\s*\{\s*method:\s*'POST',\s*body:\s*JSON\.stringify\(\{\s*field,\s*value\s*\}\),\s*\}\s*\);\s*\}\s*"
repl = """async function answerQuestion(leadId: string, key: string, value: string) {
  return http.req(apiPath(`/leads/${leadId}/answer`), {
    method: 'POST',
    body: JSON.stringify({ key, value, field: key }), // key zorunlu; field opsiyonel (compat)
  });
}"""

if re.search(pattern, txt, flags=re.DOTALL):
    txt = re.sub(pattern, repl, txt, flags=re.DOTALL)
else:
    # daha basit bir replace fallback
    txt = txt.replace(
        "body: JSON.stringify({ field, value }),",
        "body: JSON.stringify({ key: field, value, field }),"
    )
    # imza değişmediyse de sorun olmaz; ama imza key olsun diye bir kez daha deneyelim
    txt = txt.replace(
        "async function answerQuestion(leadId: string, field: string, value: string) {",
        "async function answerQuestion(leadId: string, key: string, value: string) {"
    )
    txt = txt.replace(
        "key: field",
        "key"
    )

p.write_text(txt, encoding="utf-8")
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
