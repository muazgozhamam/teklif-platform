'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { requireRole } from '@/lib/auth';

type JsonObject = Record<string, unknown>;


// Backend (Nest) endpoints:
//   GET  /deals/inbox/pending
//   GET  /deals/inbox/mine   (requires x-user-id)
//   POST /deals/:id/assign-to-me (requires x-user-id)
//   POST /listings/deals/:dealId/listing   (creates/updates listing from deal meta)

type Deal = {
  id: string;
  status?: string;
  createdAt?: string;
  updatedAt?: string;
  city?: string | null;
  district?: string | null;
  type?: string | null;
  rooms?: string | null;
  consultantId?: string | null;
  listingId?: string | null;
  leadId?: string | null;
};

type ConsultantStats = {
  role: 'CONSULTANT';
  dealsMineOpen: number;
  dealsReadyForListing: number;
  listingsDraft: number;
  listingsPublished: number;
  listingsSold: number;
};

function getErrorMessage(e: unknown, fallback: string) {
  if (typeof e === 'string') return e;
  if (e && typeof e === 'object') {
    const o = e as { message?: string; data?: { message?: string } };
    return o.data?.message || o.message || fallback;
  }
  return fallback;
}

function fmtTitle(d: Deal) {
  const parts = [
    d.type || undefined,
    d.rooms || undefined,
    [d.city, d.district].filter(Boolean).join(' / ') || undefined,
  ].filter(Boolean);
  return parts.length ? parts.join(' • ') : d.id;
}

function badge(status?: string) {
  const s = (status || '').toUpperCase();
  const base: React.CSSProperties = {
    display: 'inline-flex',
    alignItems: 'center',
    height: 22,
    padding: '0 8px',
    borderRadius: 999,
    fontSize: 12,
    fontWeight: 700,
    border: '1px solid #eee',
    background: '#fafafa',
    color: '#444',
  };
  if (s === 'OPEN') return { ...base, background: '#fff7ed', borderColor: '#fed7aa', color: '#9a3412' };
  if (s === 'ASSIGNED') return { ...base, background: '#ecfdf5', borderColor: '#a7f3d0', color: '#065f46' };
  if (s === 'READY_FOR_LISTING') return { ...base, background: '#eff6ff', borderColor: '#bfdbfe', color: '#1d4ed8' };
  if (s === 'CLOSED') return { ...base, background: '#f3f4f6', borderColor: '#e5e7eb', color: '#374151' };
  return base;
}


function normStatus(s?: string) {
  return String(s || '').trim().toUpperCase();
}

function isActiveForTab(tab: 'pending' | 'mine', status?: string) {
  const st = normStatus(status);
  if (tab === 'pending') return st === 'OPEN';
  return st === 'ASSIGNED' || st === 'READY_FOR_LISTING' || st === 'READY_FOR_MATCHING';
}

function decodeJwtPayload(token: string): { sub?: string; role?: string } {
  try {
    const parts = String(token || '').split('.');
    if (parts.length < 2) return {};
    let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const pad = b64.length % 4;
    if (pad) b64 += '='.repeat(4 - pad);
    const json = atob(b64);
    return (JSON.parse(json) || {}) as unknown as JsonObject;
  } catch {
    return {};
  }
}

function getLocalUserId() {
  if (typeof window === 'undefined') return '';
  const stored = String(localStorage.getItem('x-user-id') || '').trim();
  const token = String(localStorage.getItem('accessToken') || '').trim();
  const jwtSub = String(decodeJwtPayload(token)?.sub || '').trim();

  // Prefer JWT sub; self-heal localStorage if stale/missing
  const resolved = jwtSub || stored;
  if (resolved && resolved !== stored) {
    try { localStorage.setItem('x-user-id', resolved); } catch {}
  }
  return resolved;
}

export default function ConsultantInboxPage() {
  const searchParams = useSearchParams();
  const [allowed] = useState(() => requireRole(['CONSULTANT']));
  const [tab, setTab] = useState<'pending' | 'mine'>('pending');
  const [pending, setPending] = useState<Deal[]>([]);
  const [mine, setMine] = useState<Deal[]>([]);
  const [q, setQ] = useState('');
  const [showCompleted, setShowCompleted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [stats, setStats] = useState<ConsultantStats | null>(null);
  const [statsLoading, setStatsLoading] = useState(true);
  const [statsErr, setStatsErr] = useState<string | null>(null);
  const [focusedDealId, setFocusedDealId] = useState('');

  const [uid, setUid] = useState<string>('');

  useEffect(() => {
    // Hydration-safe: read localStorage after mount
    setUid(getLocalUserId());
  }, []);

  useEffect(() => {
    const dealId = String(searchParams.get('dealId') || '').trim();
    const requestedTab = String(searchParams.get('tab') || '').trim().toLowerCase();
    if (dealId) {
      setFocusedDealId(dealId);
      setQ(dealId);
    }
    if (requestedTab === 'mine' || requestedTab === 'pending') {
      setTab(requestedTab);
    }
  }, [searchParams]);

  const listRaw = useMemo(() => (tab === 'pending' ? pending : mine), [tab, pending, mine]);

  const listActiveRaw = useMemo(() => {
    if (showCompleted) return listRaw;
    return listRaw.filter((d) => isActiveForTab(tab, d.status));
  }, [listRaw, tab, showCompleted]);

  const pendingCount = useMemo(() => {
    if (showCompleted) return pending.length;
    return pending.filter((d) => isActiveForTab('pending', d.status)).length;
  }, [pending, showCompleted]);

  const mineCount = useMemo(() => {
    if (showCompleted) return mine.length;
    return mine.filter((d) => isActiveForTab('mine', d.status)).length;
  }, [mine, showCompleted]);

  const list = useMemo(() => {
    const s = q.trim().toLowerCase();
    if (!s) return listActiveRaw;
    return listActiveRaw.filter((d) => {
      const hay = [
        d.id,
        d.leadId,
        d.listingId,
        d.status,
        d.city,
        d.district,
        d.type,
        d.rooms,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return hay.includes(s);
    });
  }, [listActiveRaw, q]);

  useEffect(() => {
    if (!focusedDealId) return;
    const inMine = mine.some((d) => d.id === focusedDealId);
    const inPending = pending.some((d) => d.id === focusedDealId);
    if (inMine && tab !== 'mine') setTab('mine');
    if (!inMine && inPending && tab !== 'pending') setTab('pending');
  }, [focusedDealId, mine, pending, tab]);

  async function refresh() {
    setLoading(true);
    setErr(null);
    try {
      const uid = getLocalUserId();
      const pRes = await api.get<Deal[]>('/deals/inbox/pending');
      const mRes = uid
        ? await api.get<Deal[]>('/deals/inbox/mine', { headers: { 'x-user-id': uid } })
        : ({ data: [] } as unknown as JsonObject);

      const pData: unknown = pRes?.data ?? pRes;
      const mData: unknown = mRes?.data ?? mRes;
      const pItems = Array.isArray(pData)
        ? pData
        : ((pData as { items?: Deal[] } | null | undefined)?.items ?? []);
      const mItems = Array.isArray(mData)
        ? mData
        : ((mData as { items?: Deal[] } | null | undefined)?.items ?? []);

      setPending(pItems);
      setMine(mItems);
    } catch (e: unknown) {
      console.error(e);
      setErr(getErrorMessage(e, 'Yükleme başarısız'));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!allowed) return;
    refresh();
  }, [allowed]);

  useEffect(() => {
    let mounted = true;
    async function loadStats() {
      setStatsLoading(true);
      setStatsErr(null);
      try {
        const res = await api.get<ConsultantStats | { role: string }>('/stats/me');
        const data = res.data;
        if (!mounted) return;
        if (data && (data as { role?: string }).role === 'CONSULTANT') {
          setStats(data as ConsultantStats);
        } else {
          setStats(null);
        }
      } catch (e: unknown) {
        if (!mounted) return;
        setStats(null);
        setStatsErr(getErrorMessage(e, 'İstatistik alınamadı'));
      } finally {
        if (mounted) setStatsLoading(false);
      }
    }
    loadStats();
    return () => {
      mounted = false;
    };
  }, []);

  async function assignToMe(dealId: string) {
    const uid = getLocalUserId();
    if (!uid) {
      setErr("x-user-id localStorage'da yok. Login sonrası set edilmesi gerekiyor.");
      return;
    }
    setBusyId(dealId);
    setErr(null);
    try {
      await api.post(`/deals/${dealId}/assign-to-me`, {}, { headers: { 'x-user-id': uid } });
      await refresh();
      setTab('mine');
    } catch (e: unknown) {
      console.error(e);
      setErr(getErrorMessage(e, 'Atama başarısız'));
    } finally {
      setBusyId(null);
    }
  }

  async function createOrSyncListingFromDeal(dealId: string) {
    setBusyId(dealId);
    setErr(null);
    try {
      // Backend uses dealId, and will create listing if missing or update if exists.
      const r = await api.post<unknown>(`/listings/deals/${dealId}/listing`, {});
      const listing = (r as unknown as JsonObject)?.data ?? r;
      const lid = String((listing as { id?: string } | null | undefined)?.id || '').trim();
      await refresh();
      if (lid) window.location.href = `/consultant/listings/${lid}`;
    } catch (e: unknown) {
      console.error(e);
      setErr(getErrorMessage(e, 'İlan oluşturma başarısız'));
    } finally {
      setBusyId(null);
    }
  }
  if (!allowed) {
    return (
      <main style={{ padding: 24, maxWidth: 960, margin: '0 auto', opacity: 0.8 }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="CONSULTANT"
      title="Danışman Gelen Kutusu"
      subtitle="Atanmış deal’leri sahiplen, ilan üret ve akışı yönet."
      nav={[
        { href: '/consultant', label: 'Panel' },
        { href: '/consultant/inbox', label: 'Gelen Kutusu' },
        { href: '/consultant/listings', label: 'İlanlar' },
      ]}
    >
    <div style={{ padding: 2, maxWidth: 1100, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
        <div>
          <div style={{ fontSize: 20, fontWeight: 900 }}>Danışman Gelen Kutusu</div>
          <div style={{ fontSize: 12, color: '#666', marginTop: 4 }}>
            {uid ? (
              <span>
                x-user-id: <code>{uid}</code>
              </span>
            ) : (
              <span style={{ color: '#b45309' }}>x-user-id yok (Mine endpoint boş döner)</span>
            )}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
            <button onClick={() => setTab('pending')} disabled={loading} style={{ padding: '10px 12px' }}>
            Bekleyen ({pendingCount})
          </button>
          <button onClick={() => setTab('mine')} disabled={loading} style={{ padding: '10px 12px' }}>
            Benimkiler ({mineCount})
          </button>
          <button onClick={refresh} disabled={loading} style={{ padding: '10px 12px' }}>
            Yenile
          </button>
        </div>
      </div>

      <div style={{ marginTop: 12 }}>
        {statsLoading ? (
          <div style={{ display: 'grid', gap: 10, gridTemplateColumns: 'repeat(auto-fit,minmax(160px,1fr))' }}>
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 10, gridTemplateColumns: 'repeat(auto-fit,minmax(160px,1fr))' }}>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Deal (Açık/Atanmış)</div>
              <div style={{ fontSize: 22, fontWeight: 800 }}>{stats?.dealsMineOpen ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>İlana Hazır</div>
              <div style={{ fontSize: 22, fontWeight: 800 }}>{stats?.dealsReadyForListing ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Taslak İlanlar</div>
              <div style={{ fontSize: 22, fontWeight: 800 }}>{stats?.listingsDraft ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Yayındaki İlanlar</div>
              <div style={{ fontSize: 22, fontWeight: 800 }}>{stats?.listingsPublished ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Satılan İlanlar</div>
              <div style={{ fontSize: 22, fontWeight: 800 }}>{stats?.listingsSold ?? 0}</div>
            </div>
          </div>
        )}
        {statsErr ? <div style={{ marginTop: 8, color: 'crimson' }}>{statsErr}</div> : null}
      </div>

      <div style={{ marginTop: 12, display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="id / leadId / listingId / şehir / durum ara..."
          style={{
            flex: 1,
            minWidth: 260,
            padding: 10,
            borderRadius: 10,
            border: '1px solid #e5e7eb',
            outline: 'none',
          }}
        />
        <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12 }}>
          <input
            type="checkbox"
            checked={showCompleted}
            onChange={(e) => setShowCompleted(e.target.checked)}
          />
          Tamamlananları göster (WON/LOST)
        </label>
        {focusedDealId ? (
          <button
            type="button"
            onClick={() => {
              setFocusedDealId('');
              setQ('');
            }}
            style={{ padding: '8px 10px', border: '1px solid #ddd', borderRadius: 10, background: '#fff', fontSize: 12 }}
          >
            Hedef Deal Temizle
          </button>
        ) : null}

      </div>

      {loading && <div style={{ marginTop: 12 }}>Yükleniyor...</div>}
      {err ? <AlertMessage type="error" message={err} /> : null}

      <div style={{ marginTop: 16 }}>
        {list.length === 0 && !loading && !err && (
          <div style={{ color: '#666' }}>{tab === 'mine' ? 'Benimkiler listesi boş (yalnızca aktifler). WON/LOST görmek için "Tamamlananları göster" seçeneğini aç.' : 'Bekleyen liste boş (yalnızca OPEN). Diğerlerini görmek için "Tamamlananları göster" seçeneğini aç.'}</div>
        )}

        {list.map((d) => {
          const isBusy = busyId === d.id;
          const canAssign = tab === 'pending' && (d.status || '').toUpperCase() === 'OPEN';
          const hasListing = Boolean(d.listingId);

          return (
            <div
              key={d.id}
              style={{
                border: '1px solid #eee',
                outline: focusedDealId && d.id === focusedDealId ? '2px solid #2563eb' : 'none',
                borderRadius: 14,
                padding: 14,
                marginBottom: 12,
                background: '#fff',
                boxShadow: '0 1px 0 rgba(0,0,0,0.02)',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'flex-start', flexWrap: 'wrap' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                    <div style={{ fontWeight: 900, fontSize: 16 }}>{fmtTitle(d)}</div>
                    <span style={badge(d.status)}>{d.status || '—'}</span>
                  </div>

                  <div style={{ fontSize: 12, color: '#666', marginTop: 6, lineHeight: 1.6 }}>
                    <div>
                      <b>Deal ID:</b> <code>{d.id}</code>
                    </div>
                    {d.leadId && (
                      <div>
                        <b>Lead ID:</b> <code>{d.leadId}</code>
                      </div>
                    )}
                    {d.listingId && (
                      <div>
                        <b>İlan ID:</b> <code>{d.listingId}</code>
                      </div>
                    )}
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
                  {canAssign ? (
                    <button
                      onClick={() => assignToMe(d.id)}
                      disabled={isBusy}
                      style={{ padding: '10px 12px', fontWeight: 800 }}
                    >
                      {isBusy ? 'Atanıyor...' : 'Bana Ata'}
                    </button>
                  ) : (
                    <button disabled style={{ padding: '10px 12px' }}>
                      Bana Ata
                    </button>
                  )}

                  <button
                    onClick={() => createOrSyncListingFromDeal(d.id)}
                    disabled={isBusy || !d.consultantId}
                    style={{ padding: '10px 12px', fontWeight: 800 }}
                    title={!d.consultantId ? 'Deal consultantId boş. Önce Bana Ata.' : 'Deal verisinden ilan oluştur/güncelle'}
                  >
                    {isBusy ? 'Çalışıyor...' : hasListing ? 'İlanı Eşitle' : 'İlan Oluştur'}
                  </button>

                  {d.listingId ? (
                    <button
                      onClick={() => (window.location.href = `/consultant/listings/${String(d.listingId)}`)}
                      disabled={isBusy}
                      style={{ padding: '10px 12px' }}
                    >
                      İlanı Aç
                    </button>
                  ) : (
                    <button disabled style={{ padding: '10px 12px' }}>
                      İlanı Aç
                    </button>
                  )}

                  <button
                    onClick={() => {
                      try {
                        navigator.clipboard.writeText(d.id);
                      } catch {}
                    }}
                    style={{ padding: '10px 12px' }}
                  >
                    Deal ID Kopyala
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
    </RoleShell>
  );
}
