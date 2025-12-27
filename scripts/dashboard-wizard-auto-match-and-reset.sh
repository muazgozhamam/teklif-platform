#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/wizard/page.tsx"
if [[ -f "apps/dashboard/src/app/wizard/page.tsx" ]]; then
  FILE="apps/dashboard/src/app/wizard/page.tsx"
fi

echo "==> Patch: $FILE (auto-match + reset)"

python3 - <<'PY' "$FILE"
from pathlib import Path
import sys, re

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# 1) autoMatch state ekle (yoksa)
if "const [autoMatch" not in txt:
    txt = txt.replace(
        "  const [loading, setLoading] = useState(false);\n  const [err, setErr] = useState<string | null>(null);\n  const [debug, setDebug] = useState<any>(null);",
        "  const [loading, setLoading] = useState(false);\n  const [err, setErr] = useState<string | null>(null);\n  const [debug, setDebug] = useState<any>(null);\n  const [autoMatch, setAutoMatch] = useState(true);"
    )

# 2) reset() fonksiyonu ekle (yoksa)
if "function resetAll()" not in txt:
    insert_after = "  async function doMatch() {"
    idx = txt.find(insert_after)
    if idx == -1:
        raise SystemExit("❌ doMatch() bulunamadı; dosya beklenenden farklı.")
    # doMatch'tan önce ekleyelim
    txt = txt[:idx] + """  function resetAll() {
    setErr(null);
    setLoading(false);
    setDebug(null);

    setLeadId(null);
    setDealId(null);
    setQ(null);
    setAnswer('');
    setStatus('INIT');
  }

""" + txt[idx:]

# 3) submit(): READY_FOR_MATCHING olduğunda auto match yap
# submit içinde "if (done || dealStatus === 'READY_FOR_MATCHING') {" bloğunu bulup genişletelim
pattern = r"if \(done \|\| dealStatus === 'READY_FOR_MATCHING'\) {\n\s*setStatus\('READY_FOR_MATCHING'\);\n\s*return;\n\s*}"
m = re.search(pattern, txt)
if not m:
    # v4'te küçük fark olabilir; daha toleranslı yakala
    pattern2 = r"if \(done \|\| dealStatus === 'READY_FOR_MATCHING'\) \{\s*setStatus\('READY_FOR_MATCHING'\);\s*return;\s*\}"
    m = re.search(pattern2, txt)
if not m:
    raise SystemExit("❌ submit() içinde READY_FOR_MATCHING bloğu bulunamadı.")

replacement = """if (done || dealStatus === 'READY_FOR_MATCHING') {
        // Wizard tamamlandı -> (opsiyonel) otomatik match
        setStatus('READY_FOR_MATCHING');

        if (autoMatch && dealId) {
          try {
            const mout = await matchDeal(dealId);
            setStatus('ASSIGNED');
            setDebug((prev: any) => ({ ...(prev || {}), autoMatchOut: mout }));
          } catch (e: any) {
            setErr(e?.message || String(e));
          }
        }

        return;
      }"""

txt = re.sub(pattern, replacement, txt, count=1)

# 4) UI: INIT ekranına reset yok; diğer durumlarda kontrol paneli ekle
# status !== 'INIT' bloğunun içine küçük bir toolbar ekleyelim
toolbar_marker = "{status !== 'INIT' && ("
if toolbar_marker in txt and "Auto-match" not in txt:
    txt = txt.replace(
        toolbar_marker,
        """{status !== 'INIT' && (
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginTop: 10, flexWrap: 'wrap' }}>
          <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 13, color: '#333' }}>
            <input type="checkbox" checked={autoMatch} onChange={(e) => setAutoMatch(e.target.checked)} />
            Auto-match (wizard bitince)
          </label>

          <button
            onClick={resetAll}
            style={{ padding: '8px 12px', borderRadius: 10, border: '1px solid #ddd', background: '#fff' }}
          >
            Reset / Yeni Lead
          </button>
        </div>

        """ + toolbar_marker,
        1
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
