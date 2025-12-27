#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DIR="$ROOT/apps/dashboard"

if [[ ! -d "$DASH_DIR" ]]; then
  echo "❌ apps/dashboard bulunamadı: $DASH_DIR"
  exit 1
fi

API_BASE_DEFAULT="http://localhost:3001"

echo "==> 0) Dashboard env (.env.local) ayarla"
ENV_FILE="$DASH_DIR/.env.local"
touch "$ENV_FILE"

python3 - <<'PY' "$ENV_FILE" "$API_BASE_DEFAULT"
import sys, pathlib, re
env_path = pathlib.Path(sys.argv[1])
api_base = sys.argv[2]

txt = env_path.read_text(encoding="utf-8") if env_path.exists() else ""
key = "NEXT_PUBLIC_API_BASE_URL"
line = f"{key}={api_base}\n"

if re.search(rf"^{re.escape(key)}=.*$", txt, flags=re.M):
    txt = re.sub(rf"^{re.escape(key)}=.*$", f"{key}={api_base}", txt, flags=re.M)
else:
    if txt and not txt.endswith("\n"):
        txt += "\n"
    txt += line

env_path.write_text(txt, encoding="utf-8")
print(f"✅ {key} set -> {api_base}")
PY

echo
echo "==> 1) OpenAPI dokümanını otomatik keşfet (API ayakta mı?)"
OPENAPI_JSON=""
for p in "/docs-json" "/api-json" "/swagger-json" ; do
  if curl -fsS "$API_BASE_DEFAULT$p" >/dev/null 2>&1; then
    OPENAPI_JSON="$API_BASE_DEFAULT$p"
    break
  fi
done

if [[ -z "$OPENAPI_JSON" ]]; then
  echo "❌ OpenAPI JSON bulunamadı. Şunları denedim: /docs-json, /api-json, /swagger-json"
  echo "   API çalışıyor mu? Test: curl -i $API_BASE_DEFAULT/health"
  exit 1
fi

TMP_DIR="$ROOT/.tmp"
mkdir -p "$TMP_DIR"
OPENAPI_FILE="$TMP_DIR/openapi.json"
curl -fsS "$OPENAPI_JSON" -o "$OPENAPI_FILE"
echo "✅ OpenAPI bulundu: $OPENAPI_JSON -> $OPENAPI_FILE"

echo
echo "==> 2) Dashboard içine küçük bir API istemcisi + Wizard UI dosyalarını yaz"
LIB_DIR="$DASH_DIR/src/lib"
mkdir -p "$LIB_DIR"

cat > "$LIB_DIR/api.ts" <<'TS'
/* eslint-disable @typescript-eslint/no-explicit-any */
export function apiBase(): string {
  return (process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3001").replace(/\/+$/, "");
}

async function req<T = any>(path: string, init?: RequestInit): Promise<T> {
  const url = `${apiBase()}${path}`;
  const res = await fetch(url, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers || {}),
    },
    cache: "no-store",
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} ${res.statusText} - ${text}`);
  }

  const ct = res.headers.get("content-type") || "";
  if (ct.includes("application/json")) return (await res.json()) as T;
  // fallback
  return (await res.text()) as any as T;
}

export const http = { req };
TS

# Next.js router tespiti: app router mı pages router mı?
USE_APP_ROUTER="0"
if [[ -d "$DASH_DIR/app" ]]; then USE_APP_ROUTER="1"; fi
if [[ -d "$DASH_DIR/src/app" ]]; then USE_APP_ROUTER="1"; fi

# app router kökü belirle
APP_ROOT="$DASH_DIR/app"
if [[ -d "$DASH_DIR/src/app" ]]; then APP_ROOT="$DASH_DIR/src/app"; fi

PAGES_ROOT="$DASH_DIR/pages"
if [[ -d "$DASH_DIR/src/pages" ]]; then PAGES_ROOT="$DASH_DIR/src/pages"; fi

# OpenAPI içinden kritik endpoint’leri heuristik bul
python3 - <<'PY' "$OPENAPI_FILE" "$TMP_DIR/paths.json"
import json, sys, re
openapi = json.load(open(sys.argv[1], "r", encoding="utf-8"))
paths = openapi.get("paths", {}) or {}

def has(parts, s):
    s = s.lower()
    return all(p in s for p in parts)

cands = {
  "createLead": [],
  "answerWizard": [],
  "dealByLead": [],
  "matchDeal": [],
}

for p, methods in paths.items():
    low = p.lower()
    meths = list((methods or {}).keys())

    # create lead: POST /leads
    if low.endswith("/leads") and "post" in meths:
        cands["createLead"].append(p)

    # deal by lead: GET contains deals and lead
    if "get" in meths and "deal" in low and "lead" in low:
        cands["dealByLead"].append(p)

    # match deal: POST contains /deals/ and /match
    if "post" in meths and "deal" in low and "match" in low:
        cands["matchDeal"].append(p)

    # wizard answer: POST contains lead and answer OR wizard and answer
    if "post" in meths and (("answer" in low and "lead" in low) or ("wizard" in low and "answer" in low) or ("lead" in low and "wizard" in low)):
        cands["answerWizard"].append(p)

out = {k: v for k, v in cands.items()}
json.dump(out, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("✅ endpoint candidates written:", sys.argv[2])
PY

PATHS_JSON="$TMP_DIR/paths.json"

echo
echo "==> 3) Wizard UI dosyasını üret (endpoint adaylarını embed eder)"
WIZARD_IMPL_FILE="$TMP_DIR/wizard-impl.tsx"

python3 - <<'PY' "$PATHS_JSON" "$WIZARD_IMPL_FILE"
import json, sys
paths = json.load(open(sys.argv[1], "r", encoding="utf-8"))

# Basit seçim: ilk adayı al
def pick(key):
    arr = paths.get(key) or []
    return arr[0] if arr else ""

createLead = pick("createLead")
answerWizard = pick("answerWizard")
dealByLead = pick("dealByLead")
matchDeal = pick("matchDeal")

# Not: matchDeal gibi path’lerde {id} olabilir. UI'da :id yerine template yapacağız.
# createLead genelde /leads
# dealByLead genelde /deals/by-lead/{leadId}
# answerWizard proje özel. Bulamazsa UI uyaracak.

tsx = f"""'use client';

import React, {{ useMemo, useState }} from 'react';
import {{ http }} from '@/src/lib/api';

type Qa = {{ key: string; label: string; type: 'text' | 'select' | 'number'; options?: string[] }};
type WizardState =
  | {{ phase: 'INIT' }}
  | {{ phase: 'LEAD_CREATED'; leadId: string }}
  | {{ phase: 'ASKING'; leadId: string; i: number; questions: Qa[]; answers: Record<string, any> }}
  | {{ phase: 'READY_FOR_MATCHING'; leadId: string; dealId: string; deal: any }}
  | {{ phase: 'ASSIGNED'; leadId: string; dealId: string; deal: any }};

function normalizeQuestions(payload: any): Qa[] {{
  // Bu fonksiyon API’nın wizard soru formatını “elden geldiğince” normalize eder.
  // Beklenen: [{key,label,type,options}] gibi bir yapı. Değilse, city/district/type/rooms fallback kullanır.
  const q = payload?.questions || payload?.wizardQuestions || payload?.data?.questions || payload;
  if (Array.isArray(q) && q.length) {{
    return q.map((x: any, idx: number) => {{
      const key = x.key || x.field || x.name || ['city','district','type','rooms'][idx] || `q${{idx}}`;
      const label = x.label || x.question || x.title || key;
      const type =
        x.type === 'number' ? 'number' :
        x.type === 'select' ? 'select' :
        Array.isArray(x.options) ? 'select' :
        'text';
      const options = Array.isArray(x.options) ? x.options : Array.isArray(x.choices) ? x.choices : undefined;
      return {{ key, label, type, options }};
    }});
  }}
  // fallback: senin smoke akışındaki 4 soru
  return [
    {{ key: 'city', label: 'Şehir', type: 'text' }},
    {{ key: 'district', label: 'İlçe', type: 'text' }},
    {{ key: 'type', label: 'Tip', type: 'text' }},
    {{ key: 'rooms', label: 'Oda Sayısı', type: 'text' }},
  ];
}}

async function tryGetDealByLead(leadId: string) {{
  const p = '{dealByLead}';
  if (!p) throw new Error('OpenAPI içinde "deal by lead" endpoint’i bulunamadı.');
  const path = p.replace('{{leadId}}', leadId).replace(':leadId', leadId);
  return http.req(path, {{ method: 'GET' }});
}}

async function createLead(initialText: string) {{
  const p = '{createLead}';
  if (!p) throw new Error('OpenAPI içinde "POST /leads" endpoint’i bulunamadı.');
  return http.req(p, {{ method: 'POST', body: JSON.stringify({{ initialText }}) }});
}}

async function answerWizard(leadId: string, answers: Record<string, any>) {{
  const p = '{answerWizard}';
  if (!p) {{
    throw new Error(
      'OpenAPI içinde wizard cevap endpoint’i otomatik bulunamadı. ' +
      'Muhtemel çözüm: API tarafındaki wizard answer path’ini /docs-json içinde tespit edip script’e pattern eklemek.'
    );
  }}
  const path = p.replace('{{leadId}}', leadId).replace(':leadId', leadId);

  // En yaygın payload varyantları için tek bir istek atıyoruz:
  // - {{ answers: {{city,...}} }}
  // - {{ city, district, type, rooms }}
  // - {{ key, value }} (tek tek) -> burada toplu yolluyoruz
  return http.req(path, {{
    method: 'POST',
    body: JSON.stringify({{
      ...answers,
      answers,
    }}),
  }});
}}

async function matchDeal(dealId: string) {{
  const p = '{matchDeal}';
  if (!p) throw new Error('OpenAPI içinde "POST /deals/:id/match" endpoint’i bulunamadı.');
  const path = p.replace('{{id}}', dealId).replace(':id', dealId).replace('{{dealId}}', dealId).replace(':dealId', dealId);
  return http.req(path, {{ method: 'POST' }});
}}

export default function WizardPage() {{
  const [initialText, setInitialText] = useState('Sancak mahallesinde 2+1 evim var ve acil satmak istiyorum');
  const [state, setState] = useState<WizardState>({{ phase: 'INIT' }});
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const currentQ = useMemo(() => {{
    if (state.phase !== 'ASKING') return null;
    return state.questions[state.i] || null;
  }}, [state]);

  async function onStart() {{
    setErr(null);
    setLoading(true);
    try {{
      const lead = await createLead(initialText);
      const leadId = lead?.id || lead?.data?.id;
      if (!leadId) throw new Error('Lead id bulunamadı (POST /leads response).');
      // Soruları API’dan çekmeye çalış: çoğu projede createLead response içinde veya ayrı endpoint’te olur.
      // Burada: createLead response’undan normalize etmeyi deniyoruz.
      const questions = normalizeQuestions(lead);
      setState({{ phase: 'ASKING', leadId, i: 0, questions, answers: {{}} }});
    }} catch (e: any) {{
      setErr(e?.message || String(e));
    }} finally {{
      setLoading(false);
    }}
  }}

  async function onAnswer(value: any) {{
    if (state.phase !== 'ASKING') return;
    setErr(null);
    setLoading(true);
    try {{
      const q = state.questions[state.i];
      const answers = {{ ...state.answers, [q.key]: value }};

      // Son soruya geldiysek topluca gönder (senin smoke akışına benzer)
      const isLast = state.i >= state.questions.length - 1;
      if (!isLast) {{
        setState({{ ...state, i: state.i + 1, answers }});
        return;
      }}

      // Wizard answers gönder
      await answerWizard(state.leadId, answers);

      // Deal'ı leadId ile al
      const deal = await tryGetDealByLead(state.leadId);
      const dealId = deal?.id || deal?.data?.id || deal?.deal?.id;
      const status = deal?.status || deal?.data?.status || deal?.deal?.status;

      if (!dealId) throw new Error('Deal id bulunamadı (GET deal by lead response).');

      if (status === 'READY_FOR_MATCHING' || status === 'READY') {{
        setState({{ phase: 'READY_FOR_MATCHING', leadId: state.leadId, dealId, deal }});
      }} else {{
        // yine de ekranda göster
        setState({{ phase: 'READY_FOR_MATCHING', leadId: state.leadId, dealId, deal }});
      }}
    }} catch (e: any) {{
      setErr(e?.message || String(e));
    }} finally {{
      setLoading(false);
    }}
  }}

  async function onMatch() {{
    if (state.phase !== 'READY_FOR_MATCHING') return;
    setErr(null);
    setLoading(true);
    try {{
      const out = await matchDeal(state.dealId);
      setState({{ phase: 'ASSIGNED', leadId: state.leadId, dealId: state.dealId, deal: out }});
    }} catch (e: any) {{
      setErr(e?.message || String(e));
    }} finally {{
      setLoading(false);
    }}
  }}

  return (
    <div style={{{{ maxWidth: 720, margin: '40px auto', padding: 16, fontFamily: 'ui-sans-serif, system-ui' }}}}>
      <h1 style={{{{ fontSize: 28, marginBottom: 8 }}}}>Wizard → Match</h1>
      <p style={{{{ marginTop: 0, color: '#555' }}}}>
        API Base: <code>{{process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001'}}</code>
      </p>

      {err && (
        <div style={{{{ background: '#fee', border: '1px solid #f99', padding: 12, borderRadius: 8, marginBottom: 12 }}}}>
          <b>Hata</b>
          <div style={{{{ whiteSpace: 'pre-wrap' }}}}>{err}</div>
          <div style={{{{ marginTop: 8, color: '#666' }}}}>
            Endpoint adayları OpenAPI’dan otomatik seçildi. Gerekirse script raporundan pattern genişletiriz.
          </div>
        </div>
      )}

      {state.phase === 'INIT' && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <label>
            Başlangıç metni
            <textarea
              value={initialText}
              onChange={(e) => setInitialText(e.target.value)}
              rows={4}
              style={{{{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #ddd' }}}}
            />
          </label>
          <button
            onClick={onStart}
            disabled={loading}
            style={{{{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#111', color: '#fff' }}}}
          >
            {loading ? '...' : 'Lead oluştur ve başla'}
          </button>
        </div>
      )}

      {state.phase === 'ASKING' && currentQ && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <div style={{{{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}}}>
            <div style={{{{ fontSize: 14, color: '#666' }}}}>
              Lead: <code>{state.leadId}</code>
            </div>
            <div style={{{{ marginTop: 8, fontSize: 20 }}}}>{currentQ.label}</div>
          </div>

          <WizardAnswer
            q={currentQ}
            onSubmit={onAnswer}
            loading={loading}
          />

          <div style={{{{ fontSize: 12, color: '#777' }}}}>
            Soru {state.i + 1} / {state.questions.length}
          </div>
        </div>
      )}

      {state.phase === 'READY_FOR_MATCHING' && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <div style={{{{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}}}>
            <div>Lead: <code>{state.leadId}</code></div>
            <div>Deal: <code>{state.dealId}</code></div>
            <div style={{{{ marginTop: 8 }}}}>
              <button
                onClick={onMatch}
                disabled={loading}
                style={{{{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#111', color: '#fff' }}}}
              >
                {loading ? '...' : 'Match çalıştır'}
              </button>
            </div>
          </div>

          <details>
            <summary>Deal JSON</summary>
            <pre style={{{{ whiteSpace: 'pre-wrap' }}}}>{JSON.stringify(state.deal, null, 2)}</pre>
          </details>
        </div>
      )}

      {state.phase === 'ASSIGNED' && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <div style={{{{ padding: 12, border: '1px solid #d2f5d2', background: '#f4fff4', borderRadius: 10, border: '1px solid #9ee29e' }}}}>
            <b>ASSIGNED</b>
            <div>Lead: <code>{state.leadId}</code></div>
            <div>Deal: <code>{state.dealId}</code></div>
          </div>

          <details open>
            <summary>Match response JSON</summary>
            <pre style={{{{ whiteSpace: 'pre-wrap' }}}}>{JSON.stringify(state.deal, null, 2)}</pre>
          </details>
        </div>
      )}

      <hr style={{{{ margin: '24px 0' }}}} />
      <div style={{{{ fontSize: 12, color: '#666' }}}}>
        OpenAPI’dan seçilen endpoint adayları:
        <ul>
          <li>createLead: <code>{'{createLead}' or '(bulunamadı)'}</code></li>
          <li>answerWizard: <code>{'{answerWizard}' or '(bulunamadı)'}</code></li>
          <li>dealByLead: <code>{'{dealByLead}' or '(bulunamadı)'}</code></li>
          <li>matchDeal: <code>{'{matchDeal}' or '(bulunamadı)'}</code></li>
        </ul>
      </div>
    </div>
  );
}}

function WizardAnswer({{ q, onSubmit, loading }}: {{ q: Qa; onSubmit: (v: any) => void; loading: boolean }}) {{
  const [v, setV] = useState('');

  function submit() {{
    onSubmit(v);
    setV('');
  }}

  return (
    <div style={{{{ display: 'grid', gap: 10 }}}}>
      <input
        value={v}
        onChange={(e) => setV(e.target.value)}
        placeholder="Cevap..."
        style={{{{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #ddd' }}}}
        onKeyDown={(e) => {{
          if (e.key === 'Enter') submit();
        }}}
      />
      <button
        onClick={submit}
        disabled={loading || !v.trim()}
        style={{{{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#fff' }}}}
      >
        {loading ? '...' : 'Gönder'}
      </button>
    </div>
  );
}}
"""
open(sys.argv[2], "w", encoding="utf-8").write(tsx)
print("✅ wizard page impl prepared:", sys.argv[2])
PY

# Dosyayı uygun Next router dizinine yaz
if [[ "$USE_APP_ROUTER" == "1" ]]; then
  echo "==> 4) App Router tespit edildi. $APP_ROOT/wizard/page.tsx yazılıyor"
  mkdir -p "$APP_ROOT/wizard"
  cp "$WIZARD_IMPL_FILE" "$APP_ROOT/wizard/page.tsx"
else
  echo "==> 4) Pages Router tespit edildi. $PAGES_ROOT/wizard.tsx yazılıyor"
  mkdir -p "$PAGES_ROOT"
  cp "$WIZARD_IMPL_FILE" "$PAGES_ROOT/wizard.tsx"
fi

echo
echo "==> 5) Ana sayfaya Wizard linki ekle (script ile patch)"
python3 - <<'PY' "$DASH_DIR" "$USE_APP_ROUTER"
import sys, pathlib, re

dash = pathlib.Path(sys.argv[1])
use_app = sys.argv[2] == "1"

candidates = []
if use_app:
    for p in [dash/"src/app/page.tsx", dash/"app/page.tsx"]:
        if p.exists(): candidates.append(p)
else:
    for p in [dash/"src/pages/index.tsx", dash/"pages/index.tsx"]:
        if p.exists(): candidates.append(p)

if not candidates:
    print("⚠️ Ana sayfa dosyası bulunamadı; link eklenmedi (wizard sayfası yine de hazır).")
    sys.exit(0)

p = candidates[0]
txt = p.read_text(encoding="utf-8")

# Basit bir link ekle: eğer zaten varsa dokunma
if "/wizard" in txt:
    print(f"✅ Link zaten var: {p}")
    sys.exit(0)

# React JSX içine minimal link eklemeye çalış
insert = '\n      <div style={{marginTop: 12}}><a href="/wizard">Wizard ekranına git →</a></div>\n'
m = re.search(r"</h1>", txt)
if m:
    idx = m.end()
    txt = txt[:idx] + insert + txt[idx:]
else:
    # fallback: dosya sonuna ekle (riskli değil)
    txt += "\n" + insert + "\n"

p.write_text(txt, encoding="utf-8")
print(f"✅ Wizard link eklendi: {p}")
PY

echo
echo "==> 6) Endpoint aday raporu"
cat "$PATHS_JSON" || true

echo
echo "✅ DONE."
echo "Çalıştırma:"
echo "  cd $DASH_DIR"
echo "  pnpm dev"
echo
echo "Dashboard:"
echo "  http://localhost:3000/wizard (veya Next başka port seçerse terminalde yazar)"
