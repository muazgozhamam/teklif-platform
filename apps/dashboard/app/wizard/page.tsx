'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React, { useState } from 'react';
import { http } from '@/src/lib/api';

type NextQ = { done: boolean; dealId?: string; key?: string; question?: string };

function normalizeNextQ(raw: any): NextQ {
  if (!raw) return { done: false };

  // Direct
  if ((raw.key || raw.field) && raw.question) {
    return { done: !!raw.done, dealId: raw.dealId, key: raw.key || raw.field, question: raw.question };
  }

  // Nested next
  if (raw.next && (raw.next.key || raw.next.field) && raw.next.question) {
    return {
      done: !!raw.done,
      dealId: raw.dealId || raw.next.dealId,
      key: raw.next.key || raw.next.field,
      question: raw.next.question,
    };
  }

  // Wrapped data
  if (raw.data) return normalizeNextQ(raw.data);

  // Only done
  if (typeof raw.done === 'boolean') return { done: raw.done };

  return { done: false };
}

async function createLead(initialText: string) {
  return http.req('/leads', { method: 'POST', body: JSON.stringify({ initialText }) });
}

async function getDealByLead(leadId: string) {
  return http.req(`/deals/by-lead/${leadId}`, { method: 'GET' });
}

async function getNextQuestion(leadId: string): Promise<{ raw: any; nq: NextQ }> {
  const raw = await http.req(`/leads/${leadId}/next`, { method: 'GET' });
  return { raw, nq: normalizeNextQ(raw) };
}

async function wizardAnswer(leadId: string, key: string, answer: string) {
  // IMPORTANT: wizard akışını ilerleten endpoint
  return http.req(`/leads/${leadId}/wizard/answer`, {
    method: 'POST',
    body: JSON.stringify({ key, answer }),
  });
}

async function matchDeal(dealId: string) {
  return http.req(`/deals/${dealId}/match`, { method: 'POST' });
}

export default function WizardPage() {
  const [initialText, setInitialText] = useState('Sancak mahallesinde 2+1 evim var ve acil satmak istiyorum');

  const [leadId, setLeadId] = useState<string | null>(null);
  const [dealId, setDealId] = useState<string | null>(null);

  const [q, setQ] = useState<NextQ | null>(null);
  const [answer, setAnswer] = useState('');

  const [status, setStatus] = useState<'INIT' | 'ASKING' | 'READY_FOR_MATCHING' | 'ASSIGNED'>('INIT');
  const [loading, setLoading] = useState(false);
  const [autoMatch, setAutoMatch] = useState(true);

  const [err, setErr] = useState<string | null>(null);
  const [debug, setDebug] = useState<any>(null);

  function resetAll() {
    setErr(null);
    setDebug(null);

    setLeadId(null);
    setDealId(null);
    setQ(null);
    setAnswer('');
    setStatus('INIT');
  }

  async function start() {
    setErr(null);
    setLoading(true);
    try {
      const lead = await createLead(initialText);
      const id = lead?.id || lead?.data?.id;
      if (!id) throw new Error('POST /leads response içinde id yok.');
      setLeadId(id);

      const deal = await getDealByLead(id);
      const did = deal?.id || deal?.data?.id || deal?.deal?.id;
      if (!did) throw new Error('GET /deals/by-lead response içinde deal id yok.');
      setDealId(did);

      const { raw, nq } = await getNextQuestion(id);
      setQ(nq);
      setStatus('ASKING');
      setDebug({ lead, deal, nextRaw: raw, next: nq });
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  async function submit() {
    if (!leadId) return;
    if (!q?.key) return;

    const a = answer.trim();
    if (!a) return;

    setErr(null);
    setLoading(true);
    try {
      const out = await wizardAnswer(leadId, q.key, a);
      setAnswer('');

      // out: { ok, done, filled, deal, next }
      const done = !!out?.done;
      const deal = out?.deal || out?.data?.deal;
      const dealStatus = deal?.status;

      const next = normalizeNextQ(out?.next ?? out?.data?.next ?? out);

      setDebug((prev: any) => ({ ...(prev || {}), lastAnswerOut: out, next }));

      if (done || dealStatus === 'READY_FOR_MATCHING') {
        setStatus('READY_FOR_MATCHING');

        if (autoMatch && dealId) {
          const mout = await matchDeal(dealId);
          setDebug((prev: any) => ({ ...(prev || {}), autoMatchOut: mout }));
          setStatus('ASSIGNED');
        }

        return;
      }

      if (next?.key && next?.question) {
        setQ(next);
        setStatus('ASKING');
        return;
      }

      // fallback: tekrar /next
      const { raw, nq } = await getNextQuestion(leadId);
      setDebug((prev: any) => ({ ...(prev || {}), fallbackNextRaw: raw, fallbackNext: nq }));
      setQ(nq);
      setStatus('ASKING');
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  async function doManualMatch() {
    if (!dealId) return;
    setErr(null);
    setLoading(true);
    try {
      const mout = await matchDeal(dealId);
      setDebug((prev: any) => ({ ...(prev || {}), matchOut: mout }));
      setStatus('ASSIGNED');
    } catch (e: any) {
      setErr(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ maxWidth: 900, margin: '40px auto', padding: 16, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 34, marginBottom: 10 }}>Wizard → Match</h1>

      <div style={{ fontSize: 12, color: '#666', marginBottom: 14, lineHeight: 1.6 }}>
        <div><code>POST /leads</code></div>
        <div><code>GET /leads/:id/next</code> (response: <code>{'{done,key,question}'}</code>)</div>
        <div><code>POST /leads/:id/wizard/answer</code> (body: <code>{'{key,answer}'}</code>)</div>
        <div><code>GET /deals/by-lead/:leadId</code></div>
        <div><code>POST /deals/:id/match</code></div>
      </div>

      {err && (
        <div style={{ background: '#fee', border: '1px solid #f99', padding: 12, borderRadius: 10, marginBottom: 12 }}>
          <b>Hata</b>
          <div style={{ whiteSpace: 'pre-wrap' }}>{err}</div>
        </div>
      )}

      {status === 'INIT' ? (
        <>
          <label>
            Başlangıç metni
            <textarea
              value={initialText}
              onChange={(e) => setInitialText(e.target.value)}
              rows={5}
              style={{ width: '100%', padding: 10, borderRadius: 10, border: '1px solid #ddd', marginTop: 8 }}
            />
          </label>

          <button
            onClick={start}
            disabled={loading}
            style={{ marginTop: 14, width: '100%', padding: '12px 14px', borderRadius: 10, border: '1px solid #111', background: '#111', color: '#fff' }}
          >
            {loading ? '...' : 'Referans oluştur ve sihirbazı başlat'}
          </button>
        </>
      ) : (
        <>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginTop: 10, flexWrap: 'wrap' }}>
            <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 13, color: '#333' }}>
              <input type="checkbox" checked={autoMatch} onChange={(e) => setAutoMatch(e.target.checked)} />
              Auto-match (wizard bitince)
            </label>

            <button
              onClick={resetAll}
              style={{ padding: '8px 12px', borderRadius: 10, border: '1px solid #ddd', background: '#fff' }}
              disabled={loading}
            >
              Sıfırla / Yeni Referans
            </button>
          </div>

          <div style={{ marginTop: 14, padding: 14, border: '1px solid #eee', borderRadius: 12 }}>
            <div>Referans: <code>{leadId}</code></div>
            <div>İşlem: <code>{dealId || '(yok)'}</code></div>
            <div>Status: <b>{status}</b></div>
          </div>

          {status === 'ASKING' && q?.key && (
            <>
              <div style={{ marginTop: 14, padding: 14, border: '1px solid #eee', borderRadius: 12 }}>
                <div style={{ fontSize: 22 }}>{q.question || 'Soru'}</div>
                <div style={{ fontSize: 12, color: '#666', marginTop: 6 }}>key: <code>{q.key}</code></div>
              </div>

              <input
                value={answer}
                onChange={(e) => setAnswer(e.target.value)}
                placeholder="Cevap..."
                style={{ marginTop: 10, width: '100%', padding: 12, borderRadius: 10, border: '1px solid #ddd' }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') submit();
                }}
              />

              <button
                onClick={submit}
                disabled={loading || !answer.trim()}
                style={{ marginTop: 10, width: '100%', padding: '12px 14px', borderRadius: 10, border: '1px solid #111', background: '#fff' }}
              >
                {loading ? '...' : 'Gönder'}
              </button>
            </>
          )}

          {status === 'READY_FOR_MATCHING' && !autoMatch && (
            <button
              onClick={doManualMatch}
              disabled={loading || !dealId}
              style={{ marginTop: 14, width: '100%', padding: '12px 14px', borderRadius: 10, border: '1px solid #111', background: '#111', color: '#fff' }}
            >
              {loading ? '...' : 'Match çalıştır'}
            </button>
          )}

          {status === 'ASSIGNED' && (
            <div style={{ marginTop: 14, padding: 14, border: '1px solid #9ee29e', background: '#f4fff4', borderRadius: 12 }}>
              <b>ASSIGNED</b>
              <div>İşlem: <code>{dealId}</code></div>
            </div>
          )}
        </>
      )}

      <details style={{ marginTop: 14 }}>
        <summary>Debug JSON</summary>
        <pre style={{ whiteSpace: 'pre-wrap' }}>{JSON.stringify(debug, null, 2)}</pre>
      </details>
    </div>
  );
}
