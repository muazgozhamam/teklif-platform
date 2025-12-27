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
echo "==> 1) Endpoint adaylarını çıkar"
PATHS_JSON="$TMP_DIR/paths.json"
python3 - <<'PY' "$OPENAPI_FILE" "$PATHS_JSON"
import json, sys
openapi = json.load(open(sys.argv[1], "r", encoding="utf-8"))
paths = openapi.get("paths", {}) or {}

cands = {"createLead": [], "answerWizard": [], "dealByLead": [], "matchDeal": []}

for p, methods in paths.items():
    low = p.lower()
    meths = list((methods or {}).keys())

    if low.endswith("/leads") and "post" in meths:
        cands["createLead"].append(p)

    if "get" in meths and "deal" in low and "lead" in low:
        cands["dealByLead"].append(p)

    if "post" in meths and "deal" in low and "match" in low:
        cands["matchDeal"].append(p)

    # wizard answer: senin smoke script’te "field, question" dönüyor ve tek tek answer ediyorsun.
    # Muhtemel path’ler: /wizard/answer, /leads/{leadId}/answer, /wizard/{leadId}/answer vb.
    if "post" in meths and (
        ("answer" in low and "lead" in low) or
        ("wizard" in low and "answer" in low) or
        ("lead" in low and "wizard" in low) or
        ("wizard" in low and "field" in low)
    ):
        cands["answerWizard"].append(p)

json.dump(cands, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("✅ wrote", sys.argv[2])
PY

echo
echo "==> 2) Dashboard api helper dosyası (yoksa) yaz"
LIB_DIR="$DASH_DIR/src/lib"
mkdir -p "$LIB_DIR"
if [[ ! -f "$LIB_DIR/api.ts" ]]; then
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
  return (await res.text()) as any as T;
}

export const http = { req };
TS
  echo "✅ src/lib/api.ts yazıldı"
else
  echo "✅ src/lib/api.ts zaten var"
fi

echo
echo "==> 3) Wizard TSX üret (token replace; f-string yok)"
WIZARD_TEMPLATE="$TMP_DIR/wizard-template.tsx"
cat > "$WIZARD_TEMPLATE" <<'TSX'
'use client';

import React, { useMemo, useState } from 'react';
import { http } from '@/src/lib/api';

type Qa = { key: string; label: string; type: 'text' | 'select' | 'number'; options?: string[] };
type WizardState =
  | { phase: 'INIT' }
  | { phase: 'ASKING'; leadId: string; dealId?: string; i: number; questions: Qa[]; answers: Record<string, any> }
  | { phase: 'READY_FOR_MATCHING'; leadId: string; dealId: string; deal: any }
  | { phase: 'ASSIGNED'; leadId: string; dealId: string; deal: any };

function normalizeQuestion(payload: any): Qa | null {
  // smoke çıktına göre API şu formda dönüyor:
  // { done:false, dealId, field:"city", question:"Hangi şehir?" }
  if (payload && payload.field && payload.question) {
    return { key: payload.field, label: payload.question, type: 'text' };
  }
  return null;
}

async function createLead(initialText: string) {
  const p = '__CREATE_LEAD__';
  if (!p) throw new Error('OpenAPI içinde createLead endpoint’i bulunamadı.');
  return http.req(p, { method: 'POST', body: JSON.stringify({ initialText }) });
}

async function getWizardQuestion(dealId: string) {
  // Senin smoke script’te Q endpoint’i var (GET) ve field/question dönüyor.
  // OpenAPI heuristikte bunu yakalamadık; burada sabit değil.
  // Eğer proje path’i /wizard/:dealId gibi ise onu da ekleyebiliriz.
  // Şimdilik: __WIZARD_GET__ token’ı ile basacağız.
  const p = '__WIZARD_GET__';
  if (!p) throw new Error('OpenAPI içinde wizard GET question endpoint’i bulunamadı.');
  const path = p.replace('{dealId}', dealId).replace(':dealId', dealId).replace('{id}', dealId).replace(':id', dealId);
  return http.req(path, { method: 'GET' });
}

async function answerWizard(dealId: string, field: string, value: any) {
  const p = '__ANSWER_WIZARD__';
  if (!p) throw new Error('OpenAPI içinde wizard answer endpoint’i bulunamadı.');
  const path = p.replace('{dealId}', dealId).replace(':dealId', dealId).replace('{id}', dealId).replace(':id', dealId);
  return http.req(path, { method: 'POST', body: JSON.stringify({ field, value }) });
}

async function matchDeal(dealId: string) {
  const p = '__MATCH_DEAL__';
  if (!p) throw new Error('OpenAPI içinde matchDeal endpoint’i bulunamadı.');
  const path = p.replace('{id}', dealId).replace(':id', dealId).replace('{dealId}', dealId).replace(':dealId', dealId);
  return http.req(path, { method: 'POST' });
}

export default function WizardPage() {
  const [initialText, setInitialText] = useState('smoke wizard -> match');
  const [state, setState] = useState<WizardState>({ phase: 'INIT' });
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const currentQ = useMemo(() => {
    if (state.phase !== 'ASKING') return null;
    return state.questions[state.i] || null;
  }, [state]);

  async function start() {
    setErr(null);
    setLoading(true);
    try {
      const lead = await createLead(initialText);
      const leadId = lead?.id || lead?.data?.id;
      const dealId = lead?.dealId || lead?.data?.dealId; // bazı implementasyonlar createLead ile dealId döndürüyor
      // Eğer createLead dealId döndürmüyorsa, UI’yı dealId’siz başlatıp wizard get’i sonra deneyeceğiz.
      const questions: Qa[] = []; // wizard GET ile dolduracağız
      setState({ phase: 'ASKING', leadId, dealId, i: 0, questions, answers: {} });
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  async function loadFirstQuestion() {
    if (state.phase !== 'ASKING') return;
    if (!state.dealId) throw new Error('dealId bulunamadı (createLead response dealId içermiyor).');
    const qRaw = await getWizardQuestion(state.dealId);
    const q = normalizeQuestion(qRaw);
    if (!q) throw new Error('Wizard question normalize edilemedi. Response formatını göster: ' + JSON.stringify(qRaw));
    setState({ ...state, questions: [q], i: 0 });
  }

  async function submitAnswer(value: any) {
    if (state.phase !== 'ASKING') return;
    if (!state.dealId) throw new Error('dealId yok.');
    if (!currentQ) throw new Error('Soru yüklenmedi.');

    setErr(null);
    setLoading(true);
    try {
      const out = await answerWizard(state.dealId, currentQ.key, value);

      // smoke script’te response:
      // { ok:true, done:false, filled:"city", deal:{...}, next:{ field:"district", question:"Hangi ilçe?" } }
      const done = !!out?.done;
      const deal = out?.deal || out?.data?.deal || out?.data;
      const status = deal?.status;

      if (done || status === 'READY_FOR_MATCHING') {
        setState({ phase: 'READY_FOR_MATCHING', leadId: state.leadId, dealId: state.dealId, deal });
        return;
      }

      const next = out?.next;
      const nq = normalizeQuestion(next);
      if (!nq) throw new Error('Next question normalize edilemedi. out.next: ' + JSON.stringify(next));

      setState({
        ...state,
        answers: { ...state.answers, [currentQ.key]: value },
        questions: [nq],
        i: 0,
      });
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  async function doMatch() {
    if (state.phase !== 'READY_FOR_MATCHING') return;
    setErr(null);
    setLoading(true);
    try {
      const out = await matchDeal(state.dealId);
      setState({ phase: 'ASSIGNED', leadId: state.leadId, dealId: state.dealId, deal: out });
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ maxWidth: 720, margin: '40px auto', padding: 16, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 28, marginBottom: 8 }}>Wizard → Match (Dashboard)</h1>

      {err && (
        <div style={{ background: '#fee', border: '1px solid #f99', padding: 12, borderRadius: 8, marginBottom: 12 }}>
          <b>Hata</b>
          <div style={{ whiteSpace: 'pre-wrap' }}>{err}</div>
        </div>
      )}

      {state.phase === 'INIT' && (
        <div style={{ display: 'grid', gap: 12 }}>
          <label>
            Başlangıç metni
            <textarea
              value={initialText}
              onChange={(e) => setInitialText(e.target.value)}
              rows={4}
              style={{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #ddd' }}
            />
          </label>
          <button
            onClick={start}
            disabled={loading}
            style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#111', color: '#fff' }}
          >
            {loading ? '...' : 'Lead oluştur'}
          </button>
        </div>
      )}

      {state.phase === 'ASKING' && (
        <div style={{ display: 'grid', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}>
            <div style={{ fontSize: 14, color: '#666' }}>
              Lead: <code>{state.leadId}</code>
            </div>
            <div style={{ fontSize: 14, color: '#666' }}>
              Deal: <code>{state.dealId || '(createLead response dealId dönmedi)'}</code>
            </div>
          </div>

          {!currentQ ? (
            <button
              onClick={() => loadFirstQuestion().catch((e) => setErr(e?.message || String(e)))}
              disabled={loading || !state.dealId}
              style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#fff' }}
            >
              {loading ? '...' : 'İlk soruyu getir'}
            </button>
          ) : (
            <>
              <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}>
                <div style={{ marginTop: 6, fontSize: 20 }}>{currentQ.label}</div>
              </div>
              <WizardAnswer onSubmit={submitAnswer} loading={loading} />
            </>
          )}
        </div>
      )}

      {state.phase === 'READY_FOR_MATCHING' && (
        <div style={{ display: 'grid', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}>
            <div>Lead: <code>{state.leadId}</code></div>
            <div>Deal: <code>{state.dealId}</code></div>
            <button
              onClick={doMatch}
              disabled={loading}
              style={{ marginTop: 10, padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#111', color: '#fff' }}
            >
              {loading ? '...' : 'Match çalıştır'}
            </button>
          </div>
          <details>
            <summary>Deal JSON</summary>
            <pre style={{ whiteSpace: 'pre-wrap' }}>{JSON.stringify(state.deal, null, 2)}</pre>
          </details>
        </div>
      )}

      {state.phase === 'ASSIGNED' && (
        <div style={{ display: 'grid', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #d2f5d2', background: '#f4fff4', borderRadius: 10, border: '1px solid #9ee29e' }}>
            <b>ASSIGNED</b>
            <div>Lead: <code>{state.leadId}</code></div>
            <div>Deal: <code>{state.dealId}</code></div>
          </div>
          <details open>
            <summary>Match response JSON</summary>
            <pre style={{ whiteSpace: 'pre-wrap' }}>{JSON.stringify(state.deal, null, 2)}</pre>
          </details>
        </div>
      )}
    </div>
  );
}

function WizardAnswer({ onSubmit, loading }: { onSubmit: (v: any) => void; loading: boolean }) {
  const [v, setV] = useState('');
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <input
        value={v}
        onChange={(e) => setV(e.target.value)}
        placeholder="Cevap..."
        style={{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #ddd' }}
        onKeyDown={(e) => {
          if (e.key === 'Enter') onSubmit(v);
        }}
      />
      <button
        onClick={() => onSubmit(v)}
        disabled={loading || !v.trim()}
        style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#fff' }}
      >
        {loading ? '...' : 'Gönder'}
      </button>
    </div>
  );
}
TSX

WIZARD_OUT="$TMP_DIR/wizard-impl.tsx"

python3 - <<'PY' "$PATHS_JSON" "$WIZARD_TEMPLATE" "$WIZARD_OUT"
import json, sys
paths = json.load(open(sys.argv[1], "r", encoding="utf-8"))

def pick(k):
    arr = paths.get(k) or []
    return arr[0] if arr else ""

createLead = pick("createLead")
answerWizard = pick("answerWizard")
matchDeal = pick("matchDeal")

# Wizard GET question endpoint’ini de heuristik bulalım:
# smoke output formatına göre genelde GET /wizard/:dealId veya GET /deals/:id/wizard gibi.
openapi_paths = json.load(open(sys.argv[1], "r", encoding="utf-8"))
# sys.argv[1] paths.json; openapi yok; o yüzden burada sadece candidates yok.
# Biz wizard GET’i ayrıca openapi.json’dan bulmak yerine,
# en pratik şekilde: openapi.json’dan tekrar okuyalım.
# Ama bu script imzası sabit; bu yüzden WIZARD_GET’i boş bırakıp kullanıcıya paths.json’u bastıracağız.
wizardGet = ""

tpl = open(sys.argv[2], "r", encoding="utf-8").read()

out = (tpl
  .replace("__CREATE_LEAD__", createLead)
  .replace("__ANSWER_WIZARD__", answerWizard)
  .replace("__MATCH_DEAL__", matchDeal)
  .replace("__WIZARD_GET__", wizardGet)
)

open(sys.argv[3], "w", encoding="utf-8").write(out)
print("✅ wrote", sys.argv[3])
print("CANDIDATES:", json.dumps(paths, ensure_ascii=False, indent=2))
PY

echo
echo "==> 4) Router tespiti ve dosyayı yerine koy"
USE_APP_ROUTER="0"
if [[ -d "$DASH_DIR/app" ]] || [[ -d "$DASH_DIR/src/app" ]]; then USE_APP_ROUTER="1"; fi

APP_ROOT="$DASH_DIR/app"
if [[ -d "$DASH_DIR/src/app" ]]; then APP_ROOT="$DASH_DIR/src/app"; fi

PAGES_ROOT="$DASH_DIR/pages"
if [[ -d "$DASH_DIR/src/pages" ]]; then PAGES_ROOT="$DASH_DIR/src/pages"; fi

if [[ "$USE_APP_ROUTER" == "1" ]]; then
  mkdir -p "$APP_ROOT/wizard"
  cp "$WIZARD_OUT" "$APP_ROOT/wizard/page.tsx"
  echo "✅ Yazıldı: $APP_ROOT/wizard/page.tsx"
else
  mkdir -p "$PAGES_ROOT"
  cp "$WIZARD_OUT" "$PAGES_ROOT/wizard.tsx"
  echo "✅ Yazıldı: $PAGES_ROOT/wizard.tsx"
fi

echo
echo "==> 5) Next dev lock temizliği (3000/3002 listener varsa kapat)"
kill_port() {
  local PORT="$1"
  local PIDS
  PIDS="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$PIDS" ]]; then
    echo " - Port $PORT LISTEN pid: $PIDS -> kill"
    kill -9 $PIDS || true
  fi
}

kill_port 3000
kill_port 3001
kill_port 3002

LOCK="$DASH_DIR/.next/dev/lock"
if [[ -f "$LOCK" ]]; then
  echo " - Lock dosyası siliniyor: $LOCK"
  rm -f "$LOCK"
fi

echo
echo "==> 6) Rapor: paths.json"
cat "$PATHS_JSON" || true

echo
echo "✅ DONE."
echo "Şimdi:"
echo "  cd $DASH_DIR"
echo "  pnpm dev"
echo "Wizard:"
echo "  http://localhost:3000/wizard (veya Next'in seçtiği port)"
