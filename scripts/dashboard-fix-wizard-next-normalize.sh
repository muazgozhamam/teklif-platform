#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/wizard/page.tsx"
if [[ -f "apps/dashboard/src/app/wizard/page.tsx" ]]; then
  FILE="apps/dashboard/src/app/wizard/page.tsx"
fi

echo "==> Patch: $FILE"

python3 - <<'PY' "$FILE"
from pathlib import Path
p = Path(__import__("sys").argv[1])
txt = p.read_text(encoding="utf-8")

# 1) normalize helper ekle (yoksa)
if "function normalizeQ" not in txt:
    insert_point = "type Q = { done: boolean; dealId?: string; field?: string; question?: string };"
    if insert_point not in txt:
        raise SystemExit("❌ Beklenen type Q satırı bulunamadı, dosya beklenenden farklı.")
    txt = txt.replace(insert_point, insert_point + """

function normalizeQ(raw: any): Q {
  if (!raw) return { done: false };

  // Beklenen: { done, field, question }
  if (raw.field && raw.question) return raw as Q;

  // Alternatif: { done, next: { field, question } }
  if (raw.next && raw.next.field && raw.next.question) {
    return { ...raw.next, done: !!raw.done, dealId: raw.dealId || raw.next.dealId } as Q;
  }

  // Alternatif: { data: { field, question } } gibi wrapper
  if (raw.data && raw.data.field && raw.data.question) return raw.data as Q;

  // Alternatif: { data: { next: { field, question } } }
  if (raw.data && raw.data.next && raw.data.next.field && raw.data.next.question) {
    return { ...raw.data.next, done: !!raw.data.done, dealId: raw.data.dealId || raw.data.next.dealId } as Q;
  }

  // fallback: done flag’i varsa koru
  if (typeof raw.done === 'boolean') return { done: raw.done } as Q;

  return { done: false } as Q;
}
""")

# 2) start() içindeki getNextQuestion sonrası setQ(nq) -> setQ(normalizeQ(nq))
txt = txt.replace("const nq = await getNextQuestion(id);\n      setQ(nq);",
                  "const nqRaw = await getNextQuestion(id);\n      const nq = normalizeQ(nqRaw);\n      setQ(nq);\n      setDebug({ lead, deal, nqRaw, nq });")

# 3) submit() içindeki fallback GET ile çekilen nq setQ(nq) -> normalize
txt = txt.replace("const nq = await getNextQuestion(leadId);\n        setQ(nq);\n        setDebug((prev: any) => ({ ...(prev || {}), fallbackNextGet: nq }));",
                  "const nqRaw = await getNextQuestion(leadId);\n        const nq = normalizeQ(nqRaw);\n        setQ(nq);\n        setDebug((prev: any) => ({ ...(prev || {}), fallbackNextGetRaw: nqRaw, fallbackNextGet: nq }));")

# 4) UI: ASKING ama field yoksa raw göster (görsel olarak blok ekleyelim)
marker = "{status === 'ASKING' && q?.field && ("
if marker in txt and "Raw next response" not in txt:
    txt = txt.replace(marker, """{status === 'ASKING' && !q?.field && (
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}>
            <b>Raw next response (field/question bulunamadı)</b>
            <div style={{ fontSize: 12, color: '#666', marginTop: 6 }}>
              Debug JSON'u açıp <code>nqRaw</code> alanına bak.
            </div>
          </div>
        )}

        """ + marker)

p.write_text(txt, encoding="utf-8")
print("✅ Patched:", p)
PY

echo
echo "✅ DONE."
echo "Şimdi dashboard'u restart et (bu şart):"
echo "  (dashboard terminalinde) CTRL+C"
echo "  cd ~/Desktop/teklif-platform/apps/dashboard && pnpm dev"
echo
echo "Sonra:"
echo "  http://localhost:3000/wizard"
