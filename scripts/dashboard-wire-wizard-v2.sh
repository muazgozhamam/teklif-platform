#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DIR="$ROOT/apps/dashboard"
API_BASE_DEFAULT="http://localhost:3001"
TMP_DIR="$ROOT/.tmp"

if [[ ! -d "$DASH_DIR" ]]; then
  echo "❌ apps/dashboard bulunamadı: $DASH_DIR"
  exit 1
fi

echo "==> 0) OpenAPI JSON keşfi"
OPENAPI_JSON=""
for p in "/docs-json" "/api-json" "/swagger-json" ; do
  if curl -fsS "$API_BASE_DEFAULT$p" >/dev/null 2>&1; then
    OPENAPI_JSON="$API_BASE_DEFAULT$p"
    break
  fi
done
if [[ -z "$OPENAPI_JSON" ]]; then
  echo "❌ OpenAPI JSON bulunamadı. Denenenler: /docs-json, /api-json, /swagger-json"
  echo "   Test: curl -i $API_BASE_DEFAULT/health"
  exit 1
fi

mkdir -p "$TMP_DIR"
OPENAPI_FILE="$TMP_DIR/openapi.json"
curl -fsS "$OPENAPI_JSON" -o "$OPENAPI_FILE"
echo "✅ OpenAPI: $OPENAPI_JSON"

echo
echo "==> 1) Endpoint seçimi (smoke akışına göre)"
python3 - <<'PY' "$OPENAPI_FILE" "$TMP_DIR/selected.json"
import json, sys

openapi = json.load(open(sys.argv[1], "r", encoding="utf-8"))
paths = openapi.get("paths", {}) or {}

def has_method(path, m): return m in (paths.get(path, {}) or {})

create_lead = None
deal_by_lead = None
wizard_get = None
wizard_answer = None
match_deal = None

# 1) create lead
for p in paths.keys():
    if p.lower().endswith("/leads") and has_method(p, "post"):
        create_lead = p; break

# 2) deal by lead
for p in paths.keys():
    low = p.lower()
    if "deals" in low and "lead" in low and has_method(p, "get"):
        deal_by_lead = p; break

# 3) wizard GET next question (prefer exact)
for p in paths.keys():
    low = p.lower()
    if "wizard" in low and "next" in low and "question" in low and has_method(p, "get"):
        wizard_get = p; break

# fallback: GET that contains wizard and question
if not wizard_get:
    for p in paths.keys():
        low = p.lower()
        if "wizard" in low and "question" in low and has_method(p, "get"):
            wizard_get = p; break

# 4) wizard answer (prefer /leads/{id}/answer)
for p in paths.keys():
    low = p.lower()
    if low.startswith("/leads/") and low.endswith("/answer") and has_method(p, "post"):
        wizard_answer = p; break

# fallback: /leads/{id}/wizard/answer
if not wizard_answer:
    for p in paths.keys():
        low = p.lower()
        if "leads" in low and "wizard" in low and low.endswith("/answer") and has_method(p, "post"):
            wizard_answer = p; break

# 5) match
for p in paths.keys():
    low = p.lower()
    if "deals" in low and "match" in low and has_method(p, "post"):
        match_deal = p; break

out = {
  "createLead": create_lead,
  "dealByLead": deal_by_lead,
  "wizardGet": wizard_get,
  "wizardAnswer": wizard_answer,
  "matchDeal": match_deal,
}
json.dump(out, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("✅ selected endpoints:", json.dumps(out, ensure_ascii=False, indent=2))
PY

SEL="$TMP_DIR/selected.json"

echo
echo "==> 2) Wizard sayfasını üret (App Router)"
APP_ROOT="$DASH_DIR/app"
if [[ -d "$DASH_DIR/src/app" ]]; then APP_ROOT="$DASH_DIR/src/app"; fi
mkdir -p "$APP_ROOT/wizard"

python3 - <<'PY' "$SEL" "$APP_ROOT/wizard/page.tsx"
import json, sys, pathlib

sel = json.load(open(sys.argv[1], "r", encoding="utf-8"))

def must(k):
    v = sel.get(k)
    if not v:
        raise SystemExit(f"❌ Endpoint bulunamadı: {k}. OpenAPI içinde yok veya heuristik kaçırdı.")
    return v

CREATE = must("createLead")
DEAL_BY_LEAD = must("dealByLead")
WIZ_GET = must("wizardGet")
WIZ_ANS = must("wizardAnswer")
MATCH = must("matchDeal")

# Path param normalize helper: OpenAPI {id}/{leadId} gibi; biz replace edeceğiz.
tsx = f"""'use client';

import React, {{ useMemo, useState }} from 'react';
import {{ http }} from '@/src/lib/api';

type Qa = {{ key: string; label: string }};
type WizardState =
  | {{ phase: 'INIT' }}
  | {{ phase: 'LEAD_CREATED'; leadId: string }}
  | {{ phase: 'ASKING'; leadId: string; dealId: string; q: Qa }}
  | {{ phase: 'READY_FOR_MATCHING'; leadId: string; dealId: string; deal: any }}
  | {{ phase: 'ASSIGNED'; leadId: string; dealId: string; deal: any }};

function pathWithId(p: string, id: string) {{
  return p
    .replace('{{id}}', id).replace(':id', id)
    .replace('{{leadId}}', id).replace(':leadId', id);
}}

async function createLead(initialText: string) {{
  return http.req('{CREATE}', {{ method: 'POST', body: JSON.stringify({{ initialText }}) }});
}}

async function getDealByLead(leadId: string) {{
  const path = pathWithId('{DEAL_BY_LEAD}', leadId);
  return http.req(path, {{ method: 'GET' }});
}}

async function wizardNextQuestion(leadId: string) {{
  const path = pathWithId('{WIZ_GET}', leadId);
  return http.req(path, {{ method: 'GET' }});
}}

async function wizardAnswer(leadId: string, field: string, value: string) {{
  const path = pathWithId('{WIZ_ANS}', leadId);
  return http.req(path, {{ method: 'POST', body: JSON.stringify({{ field, value }}) }});
}}

async function matchDeal(dealId: string) {{
  const path = pathWithId('{MATCH}', dealId);
  return http.req(path, {{ method: 'POST' }});
}}

export default function WizardPage() {{
  const [initialText, setInitialText] = useState('smoke wizard -> match');
  const [state, setState] = useState<WizardState>({{ phase: 'INIT' }});
  const [answer, setAnswer] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const q = useMemo(() => (state.phase === 'ASKING' ? state.q : null), [state]);

  async function start() {{
    setErr(null);
    setLoading(true);
    try {{
      const lead = await createLead(initialText);
      const leadId = lead?.id || lead?.data?.id;
      if (!leadId) throw new Error('POST /leads response içinde leadId yok.');
      setState({{ phase: 'LEAD_CREATED', leadId }});
    }} catch (e: any) {{
      setErr(e?.message || String(e));
    }} finally {{
      setLoading(false);
    }}
  }}

  async function loadQuestion() {{
    if (state.phase !== 'LEAD_CREATED') return;
    setErr(null);
    setLoading(true);
    try {{
      // 1) dealId al
      const deal = await getDealByLead(state.leadId);
      const dealId = deal?.id || deal?.data?.id || deal?.deal?.id;
      if (!dealId) throw new Error('GET /deals/by-lead response içinde dealId yok.');

      // 2) ilk soruyu çek
      const nq = await wizardNextQuestion(state.leadId);
      if (nq?.done === true) {{
        // wizard zaten bitti ise (nadiren) deal status çekelim
        setState({{ phase: 'READY_FOR_MATCHING', leadId: state.leadId, dealId, deal }});
        return;
      }}
      if (!nq?.field || !nq?.question) {{
        throw new Error('Wizard question format beklenmedik: ' + JSON.stringify(nq));
      }}
      setState({{ phase: 'ASKING', leadId: state.leadId, dealId, q: {{ key: nq.field, label: nq.question }} }});
    }} catch (e: any) {{
      setErr(e?.message || String(e));
    }} finally {{
      setLoading(false);
    }}
  }}

  async function submit() {{
    if (state.phase !== 'ASKING' || !q) return;
    const v = answer.trim();
    if (!v) return;

    setErr(null);
    setLoading(true);
    try {{
      const out = await wizardAnswer(state.leadId, q.key, v);
      setAnswer('');

      const deal = out?.deal || out?.data?.deal || out?.data;
      const done = !!out?.done;
      const status = deal?.status;

      if (done || status === 'READY_FOR_MATCHING') {{
        setState({{ phase: 'READY_FOR_MATCHING', leadId: state.leadId, dealId: state.dealId, deal }});
        return;
      }}

      const next = out?.next;
      if (!next?.field || !next?.question) {{
        throw new Error('Next question format beklenmedik: ' + JSON.stringify(next));
      }}
      setState({{ ...state, q: {{ key: next.field, label: next.question }} }});
    }} catch (e: any) {{
      setErr(e?.message || String(e));
    }} finally {{
      setLoading(false);
    }}
  }}

  async function doMatch() {{
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
      <h1 style={{{{ fontSize: 28, marginBottom: 8 }}}}>Wizard → Match (Dashboard)</h1>

      <div style={{{{ fontSize: 12, color: '#666', marginBottom: 10 }}}}>
        Endpoints:
        <div><code>POST {CREATE}</code></div>
        <div><code>GET {DEAL_BY_LEAD}</code></div>
        <div><code>GET {WIZ_GET}</code></div>
        <div><code>POST {WIZ_ANS}</code></div>
        <div><code>POST {MATCH}</code></div>
      </div>

      {{err && (
        <div style={{{{ background: '#fee', border: '1px solid #f99', padding: 12, borderRadius: 8, marginBottom: 12 }}}}>
          <b>Hata</b>
          <div style={{{{ whiteSpace: 'pre-wrap' }}}}>{{err}}</div>
        </div>
      )}}

      {{state.phase === 'INIT' && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <label>
            Başlangıç metni
            <textarea
              value={{initialText}}
              onChange={{(e) => setInitialText(e.target.value)}}
              rows={{4}}
              style={{{{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #ddd' }}}}
            />
          </label>
          <button
            onClick={{start}}
            disabled={{loading}}
            style={{{{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#111', color: '#fff' }}}}
          >
            {{loading ? '...' : 'Lead oluştur'}}
          </button>
        </div>
      )}}

      {{state.phase === 'LEAD_CREATED' && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <div>Lead: <code>{{state.leadId}}</code></div>
          <button
            onClick={{loadQuestion}}
            disabled={{loading}}
            style={{{{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#fff' }}}}
          >
            {{loading ? '...' : 'Wizard başlat (ilk soruyu getir)'}}
          </button>
        </div>
      )}}

      {{state.phase === 'ASKING' && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <div style={{{{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}}}>
            <div>Lead: <code>{{state.leadId}}</code></div>
            <div>Deal: <code>{{state.dealId}}</code></div>
            <div style={{{{ marginTop: 8, fontSize: 20 }}}}>{{q?.label}}</div>
          </div>

          <input
            value={{answer}}
            onChange={{(e) => setAnswer(e.target.value)}}
            placeholder="Cevap..."
            style={{{{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #ddd' }}}}
            onKeyDown={{(e) => {{
              if (e.key === 'Enter') submit();
            }}}}
          />

          <button
            onClick={{submit}}
            disabled={{loading || !answer.trim()}}
            style={{{{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#fff' }}}}
          >
            {{loading ? '...' : 'Gönder'}}
          </button>
        </div>
      )}}

      {{state.phase === 'READY_FOR_MATCHING' && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <div style={{{{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}}}>
            <div>Lead: <code>{{state.leadId}}</code></div>
            <div>Deal: <code>{{state.dealId}}</code></div>
            <button
              onClick={{doMatch}}
              disabled={{loading}}
              style={{{{ marginTop: 10, padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#111', color: '#fff' }}}}
            >
              {{loading ? '...' : 'Match çalıştır'}}
            </button>
          </div>

          <details>
            <summary>Deal JSON</summary>
            <pre style={{{{ whiteSpace: 'pre-wrap' }}}}>{{JSON.stringify(state.deal, null, 2)}}</pre>
          </details>
        </div>
      )}}

      {{state.phase === 'ASSIGNED' && (
        <div style={{{{ display: 'grid', gap: 12 }}}}>
          <div style={{{{ padding: 12, border: '1px solid #d2f5d2', background: '#f4fff4', borderRadius: 10, border: '1px solid #9ee29e' }}}}>
            <b>ASSIGNED</b>
            <div>Lead: <code>{{state.leadId}}</code></div>
            <div>Deal: <code>{{state.dealId}}</code></div>
          </div>

          <details open>
            <summary>Match response JSON</summary>
            <pre style={{{{ whiteSpace: 'pre-wrap' }}}}>{{JSON.stringify(state.deal, null, 2)}}</pre>
          </details>
        </div>
      )}}
    </div>
  );
}}
"""
path = pathlib.Path(sys.argv[2])
path.write_text(tsx, encoding="utf-8")
print("✅ wrote", str(path))
PY

echo
echo "✅ DONE."
echo "Dashboard zaten çalışıyorsa sadece sayfayı yenile:"
echo "  http://localhost:3000/wizard"
