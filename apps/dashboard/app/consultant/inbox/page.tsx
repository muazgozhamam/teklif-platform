'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';

type DealLike = {
  id?: string;
  leadId?: string | null;
  city?: string;
  district?: string;
  // badge / status fields (best-effort, optional)
  consultantId?: string | null;
  linkedListingId?: string | null;
  listingId?: string | null;
  status?: string | null;
};

function getErrMsg(e: unknown, fallback: string) {
  if (e && typeof e === 'object' && 'message' in e) {
        const m = (e as Record<string, unknown>).message;
    if (typeof m === 'string' && m) return m;
  }
  return fallback;
}

type Deal = {
  id: string;
  status?: string | null;
  createdAt?: string | null;
  updatedAt?: string | null;
  city?: string | null;
  district?: string | null;
  type?: string | null;
  rooms?: string | null;
  consultantId?: string | null;
  listingId?: string | null;
  leadId?: string | null;
};

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  'http://localhost:3001';

function getUserIdFromStorage() {
  try {
    return String(window.localStorage.getItem('x-user-id') || '').trim();
  } catch {
    return '';
  }
}

function cx(...a: Array<string | false | null | undefined>) {
  return a.filter(Boolean).join(' ');
}

export default function ConsultantInboxPage() {
  const [tab, setTab] = useState<'pending' | 'mine'>('pending');
  const [userId, setUserId] = useState<string>('');
  const [pending, setPending] = useState<Deal[]>([]);
  const [mine, setMine] = useState<Deal[]>([]);

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selected, setSelected] = useState<DealLike | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
    const [loadingList, setLoadingList] = useState<boolean>(false);
  const [loadingDrawer, setLoadingDrawer] = useState<boolean>(false);

  // paging (take/skip) - tab-aware
  const [take, setTake] = useState<number>(20);
  const [pendingSkip, setPendingSkip] = useState<number>(0);
  const [mineSkip, setMineSkip] = useState<number>(0);
  const [hasMorePending, setHasMorePending] = useState<boolean>(false);
  const [hasMoreMine, setHasMoreMine] = useState<boolean>(false);

  const listReqSeq = useRef(0);
  const [claimingId, setClaimingId] = useState<string | null>(null);
  const [linkingId, setLinkingId] = useState<string | null>(null);
  const [err, setErr] = useState<string>('');
  const [lastAction, setLastAction] = useState<string>('');

  const [showDebug, setShowDebug] = useState<boolean>(false);

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async function matchDeal(dealId: string) {
    setLinkingId(dealId);
    try {
      setErr('');
      setLastAction(`match(${dealId}) userId=${userId || '(missing)'}`);
      if (!hasUserId) {
        setErr("Missing x-user-id. Click 'Set demo user' or set it in console.");
        return;
      }

      const r = await fetch(`${API_BASE}/deals/${dealId}/match`, {
        method: 'POST',
        headers: { 'x-user-id': userId },
      });

      const { json, raw } = await readJsonOrText(r);
      if (!r.ok) {
        const msg = json?.message || json?.error || raw || `HTTP ${r.status}`;
        throw new Error(`match ${r.status}: ${msg}`);
      }

      setLastAction(`matched ${dealId} (server ok)`);
      await load();
      try {
        if (selectedId && String(selectedId) == String(dealId)) {
          const d2 = await fetchDealById(dealId);
          setSelected(d2);
        }
      } catch {
        // ignore finalize refresh errors
      }
    } catch (e: unknown) {
      setErr(getErrMsg(e, 'Match failed'));
    } finally {
      setLinkingId(null);
    }
  }


  const reqSeq = useRef(0);

  const hasUserId = useMemo(() => Boolean(userId), [userId]);
  const list = tab === 'pending' ? pending : mine;

  

  function badgeStyle(kind: 'open' | 'claimed' | 'linked' | 'other') {
    const base: Record<string, string> = {
      display: 'inline-flex',
      alignItems: 'center',
      padding: '2px 8px',
      borderRadius: "999px",
      fontSize: "12px",
      fontWeight: "700",
      border: '1px solid #e5e7eb',
      background: '#f8fafc',
      color: '#111827',
      lineHeight: "1.6",
      whiteSpace: 'nowrap',
    };
    if (kind === 'open')   return { ...base, background: '#eef2ff', border: '1px solid #c7d2fe', color: '#1e1b4b' };
    if (kind === 'claimed')return { ...base, background: '#ecfeff', border: '1px solid #a5f3fc', color: '#083344' };
    if (kind === 'linked') return { ...base, background: '#f0fdf4', border: '1px solid #bbf7d0', color: '#052e16' };
    return base;
  }

  function getBadgeKind(d: DealLike | null) {
    // Safe inference based on fields we already have in API list
    // - linked if listingId exists
    // - claimed if consultantId exists
    // - otherwise open
    if (d?.listingId) return 'linked';
    if (d?.consultantId) return 'claimed';
    return 'open';
  }

  function getBadgeLabel(d: DealLike | null) {
    const k = getBadgeKind(d);
    if (k === 'linked') return 'LINKED';
    if (k === 'claimed') return 'CLAIMED';
    return (d?.status || 'OPEN').toString().toUpperCase();
  }


  /* ===== Drawer UI ===== */
  async function fetchDealById(id: string) {
    const r = await fetch(`${API_BASE}/deals/${id}`);
    const { json, raw } = await readJsonOrText(r);
    if (!r.ok) {
      const msg = json?.message || json?.error || raw || `HTTP ${r.status}`;
      throw new Error(`deal ${r.status}: ${msg}`);
    }
    return json;
  }

  async function openDrawer(id: string) {
    const seq = ++reqSeq.current;
    setSelectedId(id);
    setDrawerOpen(true);
    try {
      setLoadingDrawer(true);
      setErr('');
      const d = await fetchDealById(id);
      setSelected(d);
      setLastAction(`opened ${id}`);
    } catch (e: unknown) {
      setErr(getErrMsg(e, 'Drawer open failed'));
      setLastAction(`open failed ${id}`);
    } finally {
      if (seq === reqSeq.current) setLoadingDrawer(false);
    }
  }

  function closeDrawer() {
    setDrawerOpen(false);
  }

  async function copyText(s: string) {
    try {
      await navigator.clipboard.writeText(s);
      setLastAction(`copied: ${s}`);
    } catch {
      // fallback
      const ta = document.createElement('textarea');
      ta.value = s;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      setLastAction(`copied: ${s}`);
    }
  }

useEffect(() => {
    setUserId(getUserIdFromStorage());
  }, []);

  async function readJsonOrText(r: Response) {
    const raw = await r.text().catch(() => '');
    try {
      return { json: raw ? JSON.parse(raw) : null, raw };
    } catch {
      return { json: null, raw };
    }
  }
  async function load(which: 'pending' | 'mine' = tab) {
    const seq = ++listReqSeq.current;
    setErr('');
    setLoadingList(true);

    const tTake = Math.min(50, Math.max(1, Number(take || 20)));
    const skip = which === 'pending' ? pendingSkip : mineSkip;

    try {
      if (which === 'pending') {
        const r = await fetch(`${API_BASE}/deals/inbox/pending?take=${tTake}&skip=${skip}`, { cache: 'no-store' });
        const { json, raw } = await readJsonOrText(r);
        if (!r.ok) throw new Error(`pending ${r.status}: ${json?.message || json?.error || raw || 'error'}`);

        const arr = (json || []) as Deal[];
        if (seq !== listReqSeq.current) return; // stale
        setPending(arr);
        setHasMorePending(Array.isArray(arr) && arr.length >= tTake);
        setLastAction(`loaded pending=${arr.length} take=${tTake} skip=${skip}`);
        return;
      }

      // mine
      if (!hasUserId) {
        if (seq !== listReqSeq.current) return;
        setMine([]);
        setHasMoreMine(false);
        setLastAction(`mine skipped (missing userId)`);
        return;
      }

      const r2 = await fetch(`${API_BASE}/deals/inbox/mine?take=${tTake}&skip=${skip}`, {
        cache: 'no-store',
        headers: { 'x-user-id': userId },
      });
      const { json: j2, raw: raw2 } = await readJsonOrText(r2);
      if (!r2.ok) throw new Error(`mine ${r2.status}: ${j2?.message || j2?.error || raw2 || 'error'}`);

      const arr2 = (j2 || []) as Deal[];
      if (seq !== listReqSeq.current) return; // stale
      setMine(arr2);
      setHasMoreMine(Array.isArray(arr2) && arr2.length >= tTake);
      setLastAction(`loaded mine=${arr2.length} take=${tTake} skip=${skip}`);
    } catch (e: unknown) {
      if (seq !== listReqSeq.current) return;
      setErr(getErrMsg(e, 'Load failed'));
    } finally {
      if (seq === listReqSeq.current) setLoadingList(false);
    }
  }

  // Tab-aware load: whenever tab/userId/take/skip changes, load that tab
  useEffect(() => {
    void load(tab);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, userId, take, pendingSkip, mineSkip]);


  async function setDemoUser(id: string) {
    try {
      window.localStorage.setItem('x-user-id', id);
      window.location.reload();
    } catch {}
  }

  async function claim(dealId: string) {
  setClaimingId(dealId);
  try {

    setErr('');
    setLastAction(`claim(${dealId}) userId=${userId || '(missing)'}`);

    if (!hasUserId) {
      setErr("Missing x-user-id. Click 'Set demo user' or set it in console.");
      return;
    }

    // optimistic: move item from pending -> mine immediately
    const pendingItem = pending.find((x) => x.id === dealId) || null;
    const prevSelectedConsultantId = selected?.id === dealId ? (selected.consultantId || null) : null;
    if (pendingItem) {
      setPending((prev) => prev.filter((x) => x.id !== dealId));
      setMine((prev) => [{ ...pendingItem, consultantId: userId }, ...prev]);
      setTab('mine');
      setLastAction(`optimistic claimed ${dealId}`);
      setSelected((prev) => (prev?.id === dealId ? { ...prev, consultantId: userId } : prev));
    }
    try {
      const r = await fetch(`${API_BASE}/deals/${dealId}/assign-to-me`, {
        method: 'POST',
        headers: { 'x-user-id': userId },
      });

      const { json, raw } = await readJsonOrText(r);
      if (!r.ok) {
        const msg = json?.message || json?.error || raw || `HTTP ${r.status}`;
        throw new Error(`claim ${r.status}: ${msg}`);
      }

      setLastAction(`claimed ${dealId} (server ok)`);
      await load();
      try {
        if (selectedId && String(selectedId) == String(dealId)) {
          const d2 = await fetchDealById(dealId);
          setSelected(d2);
        }
      } catch {
        // ignore finalize refresh errors
      }
    } catch (e: unknown) {
      setErr(getErrMsg(e, 'Claim failed'));

      // rollback optimistic change if we can
      if (pendingItem) {
        setMine((prev) => prev.filter((x) => x.id !== dealId));
        setPending((prev) => [pendingItem, ...prev]);
        setTab('pending');
        setLastAction(`claim failed; rolled back ${dealId}`);
        setSelected((prev) => (prev?.id === dealId ? { ...prev, consultantId: prevSelectedConsultantId } : prev));
      }
    } finally {
    }
  } finally {
    setClaimingId(null);
  }
  // eslint-disable-next-line @typescript-eslint/no-unused-vars


}

  const TabButton = (props: { active: boolean; children: React.ReactNode; onClick: () => void; badge?: number }) => (
    <button
      onClick={props.onClick}
      className={cx(
        "inline-flex items-center gap-2 rounded-xl border px-3 py-2 text-sm font-medium transition",
        props.active
          ? "border-gray-900 bg-gray-900 text-white"
          : "border-gray-200 bg-white text-gray-900 hover:bg-gray-50"
      )}
    >
      <span>{props.children}</span>
      {typeof props.badge === 'number' ? (
        <span className={cx(
          "rounded-full px-2 py-0.5 text-xs",
          props.active ? "bg-white/15 text-white" : "bg-gray-100 text-gray-700"
        )}>
          {props.badge}
        </span>
      ) : null}
    </button>
  );

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="mx-auto max-w-5xl space-y-4 px-4 py-6">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold tracking-tight">Consultant Inbox</h1>
          <p className="mt-1 text-sm text-gray-600">
            Pending talepleri gör, üstlen, Mine sekmende yönet.
          </p>
        </div>

        <div className="flex items-center gap-2">
        <button
          onClick={() => setShowDebug((v) => !v)}
          className="rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-900 hover:bg-gray-50"
          title="Toggle debug panel"
        >
          {showDebug ? 'Hide Debug' : 'Show Debug'}
        </button>

        <button
          onClick={() => load()}
          className="rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-900 hover:bg-gray-50"
        >
          Refresh
        </button>
      </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <TabButton active={tab === 'pending'} onClick={() => setTab('pending')} badge={pending.length}>
          Pending
        </TabButton>
        <TabButton active={tab === 'mine'} onClick={() => setTab('mine')} badge={mine.length}>
          Mine
        </TabButton>

        <div className="ml-auto flex items-center gap-2 rounded-2xl border border-gray-200 bg-white px-3 py-2 text-xs text-gray-600">
          <span className="font-medium text-gray-900">x-user-id</span>
          <span className="font-mono">{userId || '(missing)'}</span>
        </div>
      
      <div className="flex flex-wrap items-center gap-2">
        <button
          onClick={() => {
            if (tab === 'pending') setPendingSkip((s) => Math.max(0, s - take));
            else setMineSkip((s) => Math.max(0, s - take));
          }}
          disabled={loadingList || (tab === 'pending' ? pendingSkip <= 0 : mineSkip <= 0)}
          className="rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-900 hover:bg-gray-50 disabled:opacity-50"
        >
          Prev
        </button>

        <button
          onClick={() => {
            if (tab === 'pending') setPendingSkip((s) => s + take);
            else setMineSkip((s) => s + take);
          }}
          disabled={loadingList || (tab === 'pending' ? !hasMorePending : !hasMoreMine)}
          className="rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-900 hover:bg-gray-50 disabled:opacity-50"
          title={(tab === 'pending' ? hasMorePending : hasMoreMine) ? 'Next page' : 'No more items'}
        >
          Next
        </button>

        <select
          value={take}
          onChange={(e) => {
            const v = Math.max(1, Math.min(50, Number(e.target.value || 20)));
            setTake(v);
            setPendingSkip(0);
            setMineSkip(0);
          }}
          disabled={loadingList}
          className="rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-900"
          title="Items per page (take)"
        >
          {[10, 20, 30, 50].map((n) => (
            <option key={n} value={n}>
              {n} / page
            </option>
          ))}
        </select>

        <div className="rounded-2xl border border-gray-200 bg-white px-3 py-2 text-xs text-gray-600">
          <span className="font-medium text-gray-900">skip</span>{' '}
          <span className="font-mono">{tab === 'pending' ? pendingSkip : mineSkip}</span>
        </div>
      </div>
</div>

      {!hasUserId && (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4">
          <div className="text-sm font-semibold text-rose-900">Missing x-user-id</div>
          <div className="mt-1 text-sm text-rose-800">
            Demo için tek tıkla userId set edebilirsin.
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <button
              onClick={() => setDemoUser('consultant_seed_1')}
              className="rounded-xl bg-gray-900 px-3 py-2 text-sm font-medium text-white hover:bg-gray-800"
            >
              Set demo user: consultant_seed_1
            </button>
            <code className="rounded-xl bg-white/60 px-3 py-2 text-xs text-gray-700">
              {"localStorage.setItem('x-user-id','consultant_seed_1'); location.reload();"}
            </code>
          </div>
        </div>
      )}
      {showDebug && (

      <div className="rounded-2xl border border-gray-200 bg-white p-3 text-xs text-gray-600">
        <div><span className="font-semibold text-gray-900">Debug</span> • loadingList: {String(loadingList)} • loadingDrawer: {String(loadingDrawer)} • tab: {tab} • API: {API_BASE}</div>
        {lastAction ? <div className="mt-1">Last action: <span className="font-mono text-gray-800">{lastAction}</span></div> : null}
      </div>
      )}

      {err ? (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-900">
          <span className="font-semibold">Error:</span> {err}
        </div>
      ) : null}

      <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white">
        {list.length === 0 ? (
          <div className="p-6 text-sm text-gray-600">
            {loadingList ? "Loading…" : "No items."}
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {list.map((d) => (
              <div key={d.id} onClick={() => openDrawer(d.id)} className="flex items-center gap-4 p-4">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <div className="truncate font-semibold">
                      {(d.city || '(no city)')}{d.district ? ` • ${d.district}` : ''}
                    </div>
                    <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-700">
                      {d.status || '-'}
                    </span>
                  </div>
                  <div className="mt-1 truncate font-mono text-xs text-gray-500">
                    id: {d.id} • leadId: {d.leadId || '-'} • consultantId: {d.consultantId || '-'}
                  </div>
                </div>

                {tab === 'pending' && !d.consultantId ? (
<button
                    onClick={(e) => { e.stopPropagation(); claim(d.id); }}
                    className="rounded-xl bg-gray-900 px-3 py-2 text-sm font-medium text-white hover:bg-gray-800 disabled:opacity-50"
                    disabled={loadingList || !hasUserId}
                    title={!hasUserId ? "Set x-user-id first" : "Assign to me"}
                  >
                    Üstlen
                  </button>
                ) : null}
              </div>
            ))}
          </div>
        )}
      </div>
      {drawerOpen ? (
        <div
          onClick={() => closeDrawer()}
          className="fixed inset-0 z-50 bg-gray-900/35"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="absolute right-0 top-0 flex h-full w-[420px] max-w-[92vw] flex-col gap-3 border-l border-gray-200 bg-white p-4 shadow-2xl transition-shadow duration-200"
          >
            <div className="sticky top-0 z-10 -mx-4 -mt-4 mb-2 flex items-center gap-2 border-b border-gray-200 bg-white/90 px-4 py-3 backdrop-blur">
              <div className="text-base font-extrabold tracking-tight text-gray-900">Talep Detayı</div>
              <div className="flex-1" />
              <button
                onClick={() => closeDrawer()}
                  className={[
                  'inline-flex items-center justify-center rounded-xl px-3 py-2 text-sm font-medium',
                  'border border-gray-200 bg-white text-gray-900 hover:bg-gray-50',
                ].join(' ')}
              >
                Kapat
              </button>
            </div>

            <div className="rounded-2xl border border-gray-100 bg-gray-50/50 p-3">
              <div className="flex flex-wrap items-center gap-2">
              <div className="text-sm font-extrabold text-gray-900">
                {(selected?.city || '(no city)')}{selected?.district ? ` - ${selected.district}` : ''}
              </div>
              <span style={badgeStyle(getBadgeKind(selected))}>
                {getBadgeLabel(selected)}
              </span>
            </div>
              <div className="mt-2 text-sm leading-relaxed text-gray-700">
                <div><b>dealId:</b> {selected?.id || selectedId}</div>
                
<div>
  <b>status:</b>{' '}
  <span style={badgeStyle(getBadgeKind(selected))}>
    {getBadgeLabel(selected)}
  </span>
</div>

                <div><b>leadId:</b> {selected?.leadId || '-'}</div>
                <div><b>consultantId:</b> {selected?.consultantId || '-'}</div>
                <div><b>listingId:</b> {selected?.listingId || '-'}</div>
              </div>

              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  onClick={() => copyText(String(selected?.id || selectedId || ''))}
                  className={[
        'inline-flex items-center justify-center rounded-xl px-3 py-2 text-sm font-medium',
        'border border-gray-200 bg-white text-gray-900 hover:bg-gray-50',
      ].join(' ')}
                >
                  DealId Kopyala
                </button>
                <button
                  onClick={() => copyText(String(selected?.leadId || ''))}
                  disabled={!selected?.leadId}
                  className={[
        'inline-flex items-center justify-center rounded-xl px-3 py-2 text-sm font-medium',
        'border border-gray-200 bg-white text-gray-900 hover:bg-gray-50',
      ].join(' ')}
                >
                  LeadId Kopyala
                </button>
                <button
                  onClick={async () => {
                    if (!selectedId) return;
                    try {
                      setLoadingList(true);
                      setErr('');
                      const d = await fetchDealById(selectedId);
                      setSelected(d);
                      setLastAction(`refreshed ${selectedId}`);
                    } catch (e: unknown) {
                      setErr(getErrMsg(e, 'Refresh failed'));
                    } finally {
                      setLoadingDrawer(false);
                    }
                  }}
                  className={[
        'inline-flex items-center justify-center rounded-xl px-3 py-2 text-sm font-medium',
        'border border-gray-200 bg-white text-gray-900 hover:bg-gray-50',
      ].join(' ')}
                >
                  Yenile
                </button>

                
{(() => {
  const kind = getBadgeKind(selected);
  const claimedBy = selected?.consultantId || '';
  const isMine = hasUserId && claimedBy && claimedBy === userId;
  const busy = Boolean(selectedId && claimingId && String(claimingId) === String(selectedId));

  const inPending = tab === 'pending';

  let label = 'Üstlen';
  let disabled = Boolean(loadingList || busy || tab !== 'pending');

  if (!inPending) {
    label = 'Üstlen (Pending sekmesinde)';
    disabled = true;
  }

  else if (!hasUserId) {
    label = 'Üstlenmek için x-user-id gerekli';
    disabled = true;
  } else if (!selectedId) {
    label = 'Üstlen';
    disabled = true;
  } else if (busy) {
    label = 'Üstleniliyor…';
    disabled = true;
  } else if (kind === 'linked') {
    label = 'Eşleşti (Linked)';
    disabled = true;
  } else if (kind === 'claimed') {
    label = isMine ? 'Üstlendi' : 'Üstlenildi';
    disabled = true;
  } else {
    label = 'Üstlen';
    disabled = Boolean(loadingList);
  }

  return (
    <div className="flex flex-wrap gap-2">
      <button
        disabled={disabled}
        onClick={async () => {
          if (disabled) return;
          if (!selectedId) return;
          await claim(selectedId);
        }}
        className={[
          'inline-flex items-center justify-center rounded-xl px-3 py-2 text-sm font-medium',
          'transition',
          disabled
            ? 'border border-gray-200 bg-gray-50 text-gray-500 cursor-not-allowed'
            : 'border border-gray-900 bg-gray-900 text-white hover:bg-gray-800',
        ].join(' ')}
        title={
          !hasUserId
            ? 'Önce x-user-id set et'
            : !selectedId
            ? 'Önce bir kayıt seç'
            : busy
            ? 'Üstlenme işlemi devam ediyor'
            : kind === 'linked'
            ? 'Bu talep bir ilana bağlanmış'
            : kind === 'claimed'
            ? (isMine ? 'Zaten sende' : 'Başka danışmanda')
            : 'Üstlen'
        }
      >
        {label}
      </button>

      {(() => {
        const linkBusy = Boolean(selectedId && linkingId && String(linkingId) === String(selectedId));
        const linkDisabled =
          Boolean(loadingList || busy || linkBusy) ||
          !hasUserId ||
          !selectedId ||
          !isMine ||
          kind === 'linked';

        const linkLabel =
          kind === 'linked' ? 'Bağlandı (Linked)' : linkBusy ? 'Bağlanıyor…' : 'İlana Bağla';

        const linkTitle =
          !hasUserId
            ? 'Önce x-user-id set et'
            : !selectedId
            ? 'Önce bir kayıt seç'
            : !isMine
            ? 'Önce bu talebi üstlenmelisin'
            : kind === 'linked'
            ? 'Zaten bir ilana bağlanmış'
            : linkBusy
            ? 'Bağlama işlemi devam ediyor'
            : 'Bu talebi ilana bağla (match)';

        return (
          <button
            disabled={linkDisabled}
            onClick={async () => {
              if (linkDisabled) return;
              if (!selectedId) return;
              await matchDeal(selectedId);
            }}
            className={[
              'inline-flex items-center justify-center rounded-xl px-3 py-2 text-sm font-medium',
              'transition',
              linkDisabled
                ? 'border border-gray-200 bg-gray-50 text-gray-500 cursor-not-allowed'
                : 'border border-gray-200 bg-white text-gray-900 hover:bg-gray-50',
            ].join(' ')}
            title={linkTitle}
          >
            {linkLabel}
          </button>
        );
      })()}
    </div>
  );
})()}</div>
            </div>

            <div style={{ marginTop: 'auto', paddingTop: 8, borderTop: '1px solid #eef2f7', fontSize: 12, color: '#64748b' }}>
              İpucu: Liste satırına tıklayarak detayı açabilirsin.
            </div>
          </div>
        </div>
      ) : null}

      </div>
    </div>
  );
}
