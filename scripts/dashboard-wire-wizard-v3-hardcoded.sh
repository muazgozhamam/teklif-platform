#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DIR="$ROOT/apps/dashboard"

APP_ROOT="$DASH_DIR/app"
if [[ -d "$DASH_DIR/src/app" ]]; then APP_ROOT="$DASH_DIR/src/app"; fi

if [[ ! -d "$APP_ROOT" ]]; then
  echo "❌ App Router bulunamadı (apps/dashboard/app veya src/app yok)."
  exit 1
fi

echo "==> 1) Wizard page yazılıyor: $APP_ROOT/wizard/page.tsx"
mkdir -p "$APP_ROOT/wizard"

cat > "$APP_ROOT/wizard/page.tsx" <<'TSX'
'use client';

import React, { useState } from 'react';
import { http } from '@/src/lib/api';

type Q = { done: boolean; dealId?: string; field?: string; question?: string };

function apiPath(p: string) {
  return p;
}

async function createLead(initialText: string) {
  return http.req(apiPath('/leads'), {
    method: 'POST',
    body: JSON.stringify({ initialText }),
  });
}

async function getNextQuestion(leadId: string): Promise<Q> {
  return http.req(apiPath(`/leads/${leadId}/next`), { method: 'GET' });
}

async function answerQuestion(leadId: string, field: string, value: string) {
  return http.req(apiPath(`/leads/${leadId}/answer`), {
    method: 'POST',
    body: JSON.stringify({ field, value }),
  });
}

async function getDealByLead(leadId: string) {
  return http.req(apiPath(`/deals/by-lead/${leadId}`), { method: 'GET' });
}

async function matchDeal(dealId: string) {
  return http.req(apiPath(`/deals/${dealId}/match`), { method: 'POST' });
}

export default function WizardPage() {
  const [initialText, setInitialText] = useState('Sancak mahallesinde 2+1 evim var ve acil satmak istiyorum');
  const [leadId, setLeadId] = useState<string | null>(null);
  const [dealId, setDealId] = useState<string | null>(null);

  const [q, setQ] = useState<Q | null>(null);
  const [answer, setAnswer] = useState('');
  const [status, setStatus] = useState<string>('INIT');

  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [debug, setDebug] = useState<any>(null);

  async function start() {
    setErr(null);
    setLoading(true);
    try {
      const lead = await createLead(initialText);
      const id = lead?.id || lead?.data?.id;
      if (!id) throw new Error('POST /leads response içinde leadId yok.');
      setLeadId(id);
      setStatus('LEAD_CREATED');

      // dealId’yi hemen çek (smoke akışı)
      const deal = await getDealByLead(id);
      const did = deal?.id || deal?.data?.id || deal?.deal?.id;
      if (!did) throw new Error('GET /deals/by-lead/:leadId response içinde dealId yok.');
      setDealId(did);

      // ilk soruyu getir
      const nq = await getNextQuestion(id);
      setQ(nq);
      setDebug({ lead, deal, nq });
      setStatus('ASKING');
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  async function submit() {
    if (!leadId) return;
    if (!q?.field) return;
    const v = answer.trim();
    if (!v) return;

    setErr(null);
    setLoading(true);
    try {
      const out = await answerQuestion(leadId, q.field, v);
      setAnswer('');

      // smoke response: { ok, done, filled, deal, next }
      const done = !!out?.done;
      const deal = out?.deal || out?.data?.deal || out?.data;
      const st = deal?.status;

      setDebug((prev: any) => ({ ...(prev || {}), lastAnswerOut: out }));

      if (done || st === 'READY_FOR_MATCHING') {
        setStatus('READY_FOR_MATCHING');
        // dealId zaten var; yine de refresh etmek istersen:
        const deal2 = await getDealByLead(leadId);
        const did2 = deal2?.id || deal2?.data?.id || deal2?.deal?.id;
        if (did2) setDealId(did2);
        setDebug((prev: any) => ({ ...(prev || {}), dealAfterDone: deal2 }));
        return;
      }

      const next = out?.next;
      if (!next?.field || !next?.question) {
        // fallback: tekrar next sorusunu GET ile çek
        const nq = await getNextQuestion(leadId);
        setQ(nq);
        setDebug((prev: any) => ({ ...(prev || {}), fallbackNextGet: nq }));
        return;
      }

      setQ(next);
      setStatus('ASKING');
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  async function doMatch() {
    if (!dealId) return;

    setErr(null);
    setLoading(true);
    try {
      const out = await matchDeal(dealId);
      setStatus('ASSIGNED');
      setDebug((prev: any) => ({ ...(prev || {}), matchOut: out }));
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ maxWidth: 760, margin: '40px auto', padding: 16, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 28, marginBottom: 8 }}>Wizard → Match</h1>

      <div style={{ fontSize: 12, color: '#666', marginBottom: 10 }}>
        <div><code>POST /leads</code></div>
        <div><code>GET /leads/:id/next</code></div>
        <div><code>POST /leads/:id/answer</code></div>
        <div><code>GET /deals/by-lead/:leadId</code></div>
        <div><code>POST /deals/:id/match</code></div>
      </div>

      {err && (
        <div style={{ background: '#fee', border: '1px solid #f99', padding: 12, borderRadius: 8, marginBottom: 12 }}>
          <b>Hata</b>
          <div style={{ whiteSpace: 'pre-wrap' }}>{err}</div>
        </div>
      )}

      <div style={{ display: 'grid', gap: 12 }}>
        {status === 'INIT' && (
          <>
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
              {loading ? '...' : 'Lead oluştur ve wizard başlat'}
            </button>
          </>
        )}

        {status !== 'INIT' && (
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}>
            <div>Lead: <code>{leadId}</code></div>
            <div>Deal: <code>{dealId || '(yok)'}</code></div>
            <div>Status: <b>{status}</b></div>
          </div>
        )}

        {status === 'ASKING' && q?.field && (
          <>
            <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 10 }}>
              <div style={{ fontSize: 18 }}>{q.question}</div>
              <div style={{ fontSize: 12, color: '#666', marginTop: 6 }}>field: <code>{q.field}</code></div>
            </div>

            <input
              value={answer}
              onChange={(e) => setAnswer(e.target.value)}
              placeholder="Cevap..."
              style={{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #ddd' }}
              onKeyDown={(e) => {
                if (e.key === 'Enter') submit();
              }}
            />

            <button
              onClick={submit}
              disabled={loading || !answer.trim()}
              style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#fff' }}
            >
              {loading ? '...' : 'Gönder'}
            </button>
          </>
        )}

        {status === 'READY_FOR_MATCHING' && (
          <button
            onClick={doMatch}
            disabled={loading || !dealId}
            style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #111', background: '#111', color: '#fff' }}
          >
            {loading ? '...' : 'Match çalıştır'}
          </button>
        )}

        {status === 'ASSIGNED' && (
          <div style={{ padding: 12, border: '1px solid #9ee29e', background: '#f4fff4', borderRadius: 10 }}>
            <b>ASSIGNED</b>
            <div>Deal: <code>{dealId}</code></div>
          </div>
        )}

        <details>
          <summary>Debug JSON</summary>
          <pre style={{ whiteSpace: 'pre-wrap' }}>{JSON.stringify(debug, null, 2)}</pre>
        </details>
      </div>
    </div>
  );
}
TSX

echo "✅ OK: wizard page updated"
echo
echo "Şimdi tarayıcı:"
echo "  http://localhost:3000/wizard"
