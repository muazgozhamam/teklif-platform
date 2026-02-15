'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { api } from '@/lib/api';

type JsonObject = Record<string, unknown>;


type Listing = {
  id: string;
  title?: string | null;
  description?: string | null;
  price?: number | null;
  currency?: string | null;
  city?: string | null;
  district?: string | null;
  type?: string | null;
  rooms?: string | null;
  status?: string | null; // DRAFT / PUBLISHED vs...
  createdAt?: string;
  updatedAt?: string;
  consultantId?: string | null;
};

function getErrorMessage(e: unknown, fallback: string) {
  if (typeof e === 'string') return e;
  if (e && typeof e === 'object') {
    const o = e as { message?: string; data?: { message?: string } };
    return o.data?.message || o.message || fallback;
  }
  return fallback;
}

function Btn({
  children,
  onClick,
  disabled,
  variant,
}: {
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  variant?: 'primary' | 'ghost';
}) {
  const base: React.CSSProperties = {
    borderRadius: 10,
    padding: '9px 12px',
    fontSize: 13,
    fontWeight: 900,
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.6 : 1,
    border: '1px solid #E5E7EB',
    background: '#fff',
  };

  const v = variant || 'ghost';
  const styles: Record<string, React.CSSProperties> = {
    ghost: { background: '#fff', color: '#111827' },
    primary: { background: '#111827', color: '#fff', border: '1px solid #111827' },
  };

  return (
    <button style={{ ...base, ...styles[v] }} onClick={disabled ? undefined : onClick} disabled={disabled}>
      {children}
    </button>
  );
}

function Pill({ children }: { children: React.ReactNode }) {
  return (
    <span
      style={{
        fontSize: 12,
        fontWeight: 900,
        padding: '4px 10px',
        borderRadius: 999,
        border: '1px solid #E5E7EB',
        color: '#111827',
        background: '#fff',
      }}
    >
      {children}
    </span>
  );
}

function fmtPrice(price: number | null | undefined, currency: string | null | undefined) {
  if (price === null || price === undefined) return '—';
  const cur = (currency || 'TRY').toUpperCase();
  try {
    return new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 0 }).format(price) + ` ${cur}`;
  } catch {
    return `${price} ${cur}`;
  }
}

function titleFrom(l: Listing) {
  const t = String(l.title ?? '').trim();
  if (t) return t;
  const parts = [l.city, l.district, l.type, l.rooms].filter(Boolean).join(' • ');
  return parts || l.id;
}

type Tab = 'all' | 'draft' | 'published';

export default function ConsultantListingsPage() {
  const [tab, setTab] = useState<Tab>('all');
  const [q, setQ] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const [draft, setDraft] = useState<Listing[]>([]);
  const [published, setPublished] = useState<Listing[]>([]);

  const [page, setPage] = useState(1);
  const pageSize = 12;

  const userId =
    typeof window !== 'undefined' && window.localStorage
      ? String(localStorage.getItem('x-user-id') || '').trim()
      : '';

  async function fetchStatus(status: string) {
    // listings.list(filters) supports consultantId and status (query params)
    const r = await api.get<{ items: Listing[] } | Listing[] | unknown>('/listings', {
      params: { consultantId: userId, status, page: 1, pageSize: 200 },
    });
    const data = (r?.data ?? r) as unknown as JsonObject;
    const items = Array.isArray(data) ? data : Array.isArray(data?.items) ? data.items : [];
    return items as Listing[];
  }

  async function load() {
    setLoading(true);
    setErr(null);
    try {
      if (!userId) {
        setErr('x-user-id bulunamadı. Lütfen tekrar login ol.');
        setDraft([]);
        setPublished([]);
        return;
      }
      const [d, p] = await Promise.all([fetchStatus('DRAFT'), fetchStatus('PUBLISHED')]);
      // newest first
      const sortDesc = (a: Listing, b: Listing) => String(b.createdAt || '').localeCompare(String(a.createdAt || ''));
      setDraft([...d].sort(sortDesc));
      setPublished([...p].sort(sortDesc));
    } catch (e: unknown) {
      console.error('listings load failed:', e);
      setErr(getErrorMessage(e, 'İlanlar yüklenemedi'));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const all = useMemo(() => {
    const m = new Map<string, Listing>();
    for (const x of [...draft, ...published]) m.set(x.id, x);
    return Array.from(m.values()).sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  }, [draft, published]);

  const list = useMemo(() => {
    const base = tab === 'draft' ? draft : tab === 'published' ? published : all;
    const qq = q.trim().toLowerCase();
    const filtered = !qq
      ? base
      : base.filter((l) => {
          const hay = [
            l.id,
            l.title,
            l.city,
            l.district,
            l.type,
            l.rooms,
            l.status,
          ]
            .filter(Boolean)
            .join(' ')
            .toLowerCase();
          return hay.includes(qq);
        });
    return filtered;
  }, [tab, q, draft, published, all]);

  const totalPages = Math.max(1, Math.ceil(list.length / pageSize));
  const pageSafe = Math.min(page, totalPages);
  const view = useMemo(() => list.slice((pageSafe - 1) * pageSize, pageSafe * pageSize), [list, pageSafe]);

  useEffect(() => {
    setPage(1);
  }, [tab, q]);

  function openListing(id: string) {
    window.location.href = `/consultant/listings/${id}`;
  }

  return (
    <div style={{ padding: 22, maxWidth: 1150, margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
        <div>
          <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: -0.2 }}>İlanlarım</div>
          <div style={{ marginTop: 6, color: '#6B7280', fontSize: 13 }}>
            consultantId: <code>{userId || '—'}</code>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <Btn onClick={() => (window.location.href = '/consultant/inbox')}>← Gelen Kutusu</Btn>
          <Btn onClick={() => load()} disabled={loading} variant="primary">
            {loading ? 'Yenileniyor…' : 'Yenile'}
          </Btn>
        </div>
      </div>

      <div style={{ marginTop: 14, display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
        <Btn onClick={() => setTab('all')} disabled={loading} variant={tab === 'all' ? 'primary' : 'ghost'}>
          Tümü <span style={{ opacity: 0.8 }}>({all.length})</span>
        </Btn>
        <Btn onClick={() => setTab('draft')} disabled={loading} variant={tab === 'draft' ? 'primary' : 'ghost'}>
          Taslak <span style={{ opacity: 0.8 }}>({draft.length})</span>
        </Btn>
        <Btn onClick={() => setTab('published')} disabled={loading} variant={tab === 'published' ? 'primary' : 'ghost'}>
          Yayında <span style={{ opacity: 0.8 }}>({published.length})</span>
        </Btn>

        <div style={{ flex: 1 }} />

        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Başlık / şehir / oda / id ara…"
          style={{
            width: 340,
            maxWidth: '100%',
            border: '1px solid #E5E7EB',
            borderRadius: 12,
            padding: 10,
            fontSize: 13,
          }}
        />
      </div>

      {err && (
        <div
          style={{
            marginTop: 14,
            padding: 12,
            borderRadius: 14,
            border: '1px solid #FECACA',
            background: '#FEF2F2',
            color: '#991B1B',
            fontSize: 13,
            fontWeight: 800,
          }}
        >
          {err}
        </div>
      )}

      <div style={{ marginTop: 14, color: '#6B7280', fontSize: 13 }}>
        Gösterilen <b>{view.length}</b> / <b>{list.length}</b> • Sayfa <b>{pageSafe}</b>/<b>{totalPages}</b>
      </div>

      <div
        style={{
          marginTop: 12,
          display: 'grid',
          gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
          gap: 12,
        }}
      >
        {view.map((l) => (
          <div
            key={l.id}
            style={{
              border: '1px solid #EEF2F7',
              borderRadius: 18,
              padding: 14,
              background: '#fff',
              display: 'grid',
              gap: 10,
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, alignItems: 'flex-start' }}>
              <div style={{ fontWeight: 950, fontSize: 14, lineHeight: 1.25 }}>{titleFrom(l)}</div>
              <Pill>{String(l.status || '—')}</Pill>
            </div>

            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <Pill>{fmtPrice(l.price ?? null, l.currency ?? 'TRY')}</Pill>
              {l.city ? <Pill>{l.city}</Pill> : null}
              {l.district ? <Pill>{l.district}</Pill> : null}
              {l.rooms ? <Pill>{l.rooms}</Pill> : null}
              {l.type ? <Pill>{l.type}</Pill> : null}
            </div>

            <div style={{ color: '#6B7280', fontSize: 12 }}>
              <div>
                ID: <code>{l.id}</code>
              </div>
              <div>createdAt: {l.createdAt || '—'}</div>
            </div>

            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <Btn variant="primary" onClick={() => openListing(l.id)}>
                Aç
              </Btn>
              <Btn
                onClick={async () => {
                  try {
                    await navigator.clipboard.writeText(l.id);
                    alert('✅ İlan ID kopyalandı');
                  } catch {
                    alert(l.id);
                  }
                }}
              >
                ID Kopyala
              </Btn>
            </div>
          </div>
        ))}
      </div>

      {list.length === 0 && !loading && !err && (
        <div style={{ marginTop: 18, color: '#6B7280', fontSize: 13 }}>
          Bu sekmede kayıt yok.
        </div>
      )}

      <div style={{ marginTop: 16, display: 'flex', gap: 10, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
        <Btn onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={pageSafe <= 1}>
          ← Önceki
        </Btn>
        <Btn onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={pageSafe >= totalPages}>
          Sonraki →
        </Btn>
      </div>

      <div style={{ marginTop: 10, color: '#6B7280', fontSize: 12 }}>
        Not: “Tümü” sekmesi DRAFT + PUBLISHED ayrı çekilip birleştirilir (API varsayılanı yalnızca PUBLISHED döndürebilir).
      </div>
    </div>
  );
}
