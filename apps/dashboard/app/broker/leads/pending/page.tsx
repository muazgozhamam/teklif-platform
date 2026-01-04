'use client';

import { useEffect, useMemo, useState, useRef } from 'react';
import { api } from '@/lib/api';
function getErrMsg(e: unknown, fallback: string) {
  try {
    if (e instanceof Error && e.message) return e.message;
  } catch {}
  try {
    const obj = e as Record<string, unknown>;
    const msg = obj['message'];
    if (typeof msg === 'string' && msg) return msg;
  } catch {}
  return fallback;
}

type Lead = {
  id: string;
  category: string;
  status: string;
  title?: string | null;
  city?: string | null;
  district?: string | null;
  neighborhood?: string | null;
  price?: number | null;
  areaM2?: number | null;
  createdAt: string;
  createdBy?: { id: string; name: string; email: string; role: string } | null;
};

export default function PendingLeadsPage() {
  const [items, setItems] = useState<Lead[]>([]);
  const [total, setTotal] = useState<number>(0);

  const [page, setPage] = useState<number>(1);
  const [pageSize, setPageSize] = useState<number>(20);

  const reqSeq = useRef(0);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [actionMsg, setActionMsg] = useState<string | null>(null);
  
  const [createdDeals, setCreatedDeals] = useState<Record<string, string>>({});
const [lastDealId, setLastDealId] = useState<string | null>(null);

  const [busy, setBusy] = useState<{ id: string; action: 'approve' | 'reject' | 'createDeal' } | null>(null);

  const title = useMemo(() => `Pending Leads (${total})`, [total]);

  function getStatus(err: unknown): number | undefined {
    const e = err as { status?: number; response?: { status?: number } };
    return e?.status ?? e?.response?.status;
  }


  function resolveApiBase() {
    const base =
      process.env.NEXT_PUBLIC_API_BASE_URL ||
      process.env.NEXT_PUBLIC_API_URL ||
      process.env.API_URL ||
      'http://localhost:3001';
    return String(base).replace(/\/+$/, '');
  }

  function openDealInInbox(dealId: string) {
    const url = `/consultant/inbox?dealId=${encodeURIComponent(dealId)}`;
    window.open(url, '_blank', 'noopener,noreferrer');
  }

  async function copyDealId(dealId: string) {
    try {
      await navigator.clipboard.writeText(dealId);
      setLastDealId(dealId);
      setActionMsg(`Copied Deal ID: ${dealId}`);
    } catch {
      setLastDealId(dealId);
      setActionMsg(`Deal ID: ${dealId}`);
    }
  }

  function openDealJson(dealId: string) {
    const url = `${resolveApiBase()}/deals/${dealId}`;
    window.open(url, '_blank', 'noopener,noreferrer');
  }


  async function load(currentPage = page, currentLimit = pageSize) {
    ++reqSeq.current;
    setLoading(true);
    setError(null);    try {
      const res = await api.get('/broker/leads/pending/paged', {
        params: { page: currentPage, limit: currentLimit },
      });

      const data = res.data as { items: Lead[]; total: number; page: number; limit: number };

            setItems(Array.isArray(data?.items) ? data.items : []);
      setTotal(typeof data?.total === 'number' ? data.total : 0);      // UX: if backend returns any deal id hints per lead, hydrate createdDeals so 'Deal Ready' persists on refresh.
      try {
        const next: Record<string, string> = {};
        const arrUnknown = (data as unknown as { items?: unknown })?.items;
        const arr = Array.isArray(arrUnknown) ? arrUnknown : [];

        for (const itUnknown of arr) {
          if (!itUnknown || typeof itUnknown !== 'object') continue;
          const it = itUnknown as Record<string, unknown>;
          const leadIdRaw = it['id'];
          const leadId = typeof leadIdRaw === 'string' ? leadIdRaw : (leadIdRaw != null ? String(leadIdRaw) : '');

          // deal id candidates
          const dealIdRaw = it['dealId'] ?? it['deal_id']
            ?? (typeof it['deal'] === 'object' && it['deal'] ? (it['deal'] as Record<string, unknown>)['id'] : undefined)
            ?? (typeof it['deal'] === 'object' && it['deal'] ? (it['deal'] as Record<string, unknown>)['dealId'] : undefined)
            ?? (typeof it['deal'] === 'object' && it['deal'] ? (it['deal'] as Record<string, unknown>)['deal_id'] : undefined);

          if (!leadId || dealIdRaw == null) continue;
          const dealId = typeof dealIdRaw === 'string' ? dealIdRaw : String(dealIdRaw);
          if (dealId) next[leadId] = dealId;
        }

        if (Object.keys(next).length) {
          setCreatedDeals((prev) => ({ ...prev, ...next }));
        }
      } catch {}

      // keep page in sync if backend clamps
      if (typeof data?.page === 'number' && data.page !== currentPage) setPage(data.page);
      if (typeof data?.limit === 'number' && data.limit !== currentLimit) setPageSize(data.limit);
    } catch (err: unknown) {
      getStatus(err);
      setError(getErrMsg(err, 'Failed to load'));
    } finally {
      setLoading(false);
    }
  }

  async function approve(id: string) {
    if (busy?.id === id) return;
    setBusy({ id, action: 'approve' });
    setActionMsg(null);

    try {
      await api.post(`/broker/leads/${id}/approve`, { brokerNote: 'OK' });
      setActionMsg('Approved.');
      await load(page, pageSize);
    } catch (err: unknown) {
      getStatus(err);
      setError(getErrMsg(err, 'Approve failed'));
    } finally {
      setBusy(null);
    }
  }

  async function reject(id: string) {
    if (busy?.id === id) return;
    setBusy({ id, action: 'reject' });
    setActionMsg(null);

    try {
      await api.post(`/broker/leads/${id}/reject`, { brokerNote: 'NO' });
      setActionMsg('Rejected.');
      await load(page, pageSize);
    } catch (err: unknown) {
      getStatus(err);
      setError(getErrMsg(err, 'Reject failed'));
    } finally {
      setBusy(null);
    }
  }


  async function createDeal(id: string) {
    // Idempotent UX: if we already have a dealId for this lead, don't call API again.
    const existing = createdDeals[id];
    if (existing) {
      setLastDealId(existing);
      setActionMsg(`Deal already exists: ${existing}`);
      return;
    }

    if (busy?.id === id) return;
    setBusy({ id, action: 'createDeal' });
    setActionMsg(null);

    try {
      const res = await api.post(`/broker/leads/${id}/deal`, {});
      const data = res.data as { ok?: boolean; dealId?: string; created?: boolean };
      if (data?.dealId) setCreatedDeals((prev) => ({ ...prev, [id]: String(data.dealId) }));
      if (!data?.dealId) throw new Error('Deal id missing from response');
      setLastDealId(data.dealId);
      setActionMsg(data.created ? `Deal created: ${data.dealId}` : `Deal already exists: ${data.dealId}`);
      await load(page, pageSize);
    } catch (err: unknown) {
      setError(getErrMsg(err, 'Create deal failed'));
    } finally {
      setBusy(null);
    }
  }

  useEffect(() => {
    void load(page, pageSize);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, pageSize]);

  const totalPages = useMemo(() => Math.max(1, Math.ceil(total / pageSize)), [total, pageSize]);

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="mx-auto max-w-5xl space-y-4 px-4 py-6">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h1 className="text-lg font-semibold tracking-tight text-gray-900">{title}</h1>
            <p className="mt-1 text-sm text-gray-600">Onayla, reddet veya lead’den deal oluştur.</p>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page <= 1 || loading}
              className="rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
            >
              Prev
            </button>

            <div className="text-sm text-gray-600">
              Page <span className="font-medium text-gray-900">{page}</span> / {totalPages}
            </div>

            <button
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page >= totalPages || loading}
              className="rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
            >
              Next
            </button>

            <select
              className="ml-2 rounded-md border bg-white px-2 py-2 text-sm"
              value={pageSize}
              onChange={(e) => {
                const v = Math.max(1, Math.min(100, Number(e.target.value || 20)));
                setPage(1);
                setPageSize(v);
              }}
              disabled={loading}
            >
              {[10, 20, 50, 100].map((n) => (
                <option key={n} value={n}>
                  {n}/page
                </option>
              ))}
            </select>
          </div>
        </div>

        {error ? (
          <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">{error}</div>
        ) : null}

        {actionMsg ? (
          <div className="rounded-md border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-800">
            {actionMsg}
          </div>
        ) : null}

        {lastDealId ? (
          <div className="flex flex-wrap items-center gap-2">
            <button
              onClick={() => openDealInInbox(String(lastDealId))}
              className="rounded-md border bg-white px-3 py-2 text-sm"
              type="button"
            >
              Open Deal
            </button>

            <button
              onClick={() => openDealJson(lastDealId)}
              className="rounded-md border bg-white px-3 py-2 text-sm"
              type="button"
            >
              Open JSON
            </button>

            <button
              onClick={() => void copyDealId(lastDealId)}
              className="rounded-md border bg-white px-3 py-2 text-sm"
              type="button"
            >
              Copy Deal ID
            </button>
          </div>
        ) : null}<div className="rounded-xl border bg-white">
          <div className="border-b px-4 py-3 text-sm text-gray-600">
            {loading ? 'Loading…' : `${items.length} item(s) shown`}
          </div>

          <div className="divide-y">
            {items.length === 0 && !loading ? (
              <div className="px-4 py-8 text-center text-sm text-gray-500">No pending leads.</div>
            ) : null}

            {items.map((l) => (
              <div key={l.id} className="flex flex-col gap-2 px-4 py-3 md:flex-row md:items-center md:justify-between">
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium text-gray-900">{l.title}</div>
                  <div className="mt-1 text-xs text-gray-600">
                    {l.city || '-'} / {l.district || '-'} {l.neighborhood ? ` / ${l.neighborhood}` : ''} • {l.status}
                  </div>
                </div>

                <div className="flex shrink-0 items-center gap-2">
                  <button
                    onClick={() => approve(l.id)}
                    disabled={busy?.id === l.id}
                    className="rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
                  >
                    {busy?.id === l.id && busy?.action === 'approve' ? 'Working…' : 'Approve'}
                  </button>

                  <button
                    type="button"
                    onClick={() => createDeal(l.id)}
                    disabled={busy?.id === l.id || !!createdDeals[l.id]}
                    className="rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
                  >
                    {busy?.id === l.id && busy?.action === 'createDeal'
                      ? 'Working…'
                      : createdDeals[l.id]
                        ? 'Deal Ready'
                        : 'Create Deal'}
                  </button>
                  {createdDeals[l.id] ? (
                    <>
                      <button
                        type="button"
                        onClick={() => openDealInInbox(String(createdDeals[l.id]))}
                        className="rounded-md border bg-white px-3 py-2 text-sm"
                      >
                        Open Deal
                      </button>
                      <button
                        type="button"
                        onClick={() => void copyDealId(String(createdDeals[l.id]))}
                        className="rounded-md border bg-white px-3 py-2 text-sm"
                      >
                        Copy Deal ID
                      </button>
                    </>
                  ) : null}


                  <button
                    onClick={() => reject(l.id)}
                    disabled={busy?.id === l.id}
                    className="rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
                  >
                    {busy?.id === l.id && busy?.action === 'reject' ? 'Working…' : 'Reject'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
