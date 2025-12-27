#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/wizard/page.tsx"
if [[ -f "apps/dashboard/src/app/wizard/page.tsx" ]]; then
  FILE="apps/dashboard/src/app/wizard/page.tsx"
fi

echo "==> Patch (key support): $FILE"

python3 - <<'PY' "$FILE"
from pathlib import Path
import re, sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# Q type: key alanını ekle
txt = re.sub(
    r"type Q = \{ done: boolean; dealId\?: string; field\?: string; question\?: string; \};",
    "type Q = { done: boolean; dealId?: string; field?: string; key?: string; question?: string };",
    txt
)

# normalizeQ: raw.key varsa field gibi davran
if "function normalizeQ" in txt:
    txt = txt.replace(
        "  // Beklenen: { done, field, question }\n  if (raw.field && raw.question) return raw as Q;",
        "  // Beklenen: { done, field|key, question }\n  if ((raw.field || raw.key) && raw.question) return ({ ...raw, field: raw.field || raw.key }) as Q;"
    )
    # next içinde key olabilir
    txt = txt.replace(
        "  if (raw.next && raw.next.field && raw.next.question) {",
        "  if (raw.next && (raw.next.field || raw.next.key) && raw.next.question) {"
    )
    txt = txt.replace(
        "    return { ...raw.next, done: !!raw.done, dealId: raw.dealId || raw.next.dealId } as Q;",
        "    return { ...raw.next, field: raw.next.field || raw.next.key, done: !!raw.done, dealId: raw.dealId || raw.next.dealId } as Q;"
    )
    # data wrapper içinde key olabilir
    txt = txt.replace(
        "  if (raw.data && raw.data.field && raw.data.question) return raw.data as Q;",
        "  if (raw.data && (raw.data.field || raw.data.key) && raw.data.question) return ({ ...raw.data, field: raw.data.field || raw.data.key }) as Q;"
    )
    txt = txt.replace(
        "  if (raw.data && raw.data.next && raw.data.next.field && raw.data.next.question) {",
        "  if (raw.data && raw.data.next && (raw.data.next.field || raw.data.next.key) && raw.data.next.question) {"
    )
    txt = txt.replace(
        "    return { ...raw.data.next, done: !!raw.data.done, dealId: raw.data.dealId || raw.data.next.dealId } as Q;",
        "    return { ...raw.data.next, field: raw.data.next.field || raw.data.next.key, done: !!raw.data.done, dealId: raw.data.dealId || raw.data.next.dealId } as Q;"
    )

# UI koşulu: q?.field yerine (q?.field || q?.key) ama biz normalize field'e bastığımız için q.field yeter.
# yine de emniyet: ASKING blok markerlarını q?.field -> (q?.field || q?.key)
txt = txt.replace("{status === 'ASKING' && q?.field && (", "{status === 'ASKING' && (q?.field || q?.key) && (")
txt = txt.replace("if (!q?.field) return;", "if (!(q?.field || q?.key)) return;")
txt = txt.replace("const out = await answerQuestion(leadId, q.field, v);", "const out = await answerQuestion(leadId, (q.field || q.key)!, v);")
txt = txt.replace("if (!q?.field) return;\n    const v = answer.trim();", "if (!(q?.field || q?.key)) return;\n    const v = answer.trim();")
txt = txt.replace("const v = answer.trim();\n    if (!v) return;\n\n    setErr(null);", "const v = answer.trim();\n    if (!v) return;\n\n    // key/field uyumu\n    const f = (q.field || q.key) as string;\n\n    setErr(null);")
# answerQuestion çağrısını f ile yap (eğer yukarıdaki replace uygulanmadıysa)
txt = txt.replace("const out = await answerQuestion(leadId, q.field, v);", "const out = await answerQuestion(leadId, f, v);")

p.write_text(txt, encoding="utf-8")
print("✅ Patched:", p)
PY

echo
echo "✅ DONE."
echo "Dashboard restart şart (lock temizliği yaptıysan zaten pnpm dev açık olacaktır)."
echo "Tarayıcı:"
echo "  http://localhost:3000/wizard  (veya terminalde yazan Local port)"
