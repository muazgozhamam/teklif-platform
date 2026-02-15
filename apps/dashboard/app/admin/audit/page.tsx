'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { requireRole } from '@/lib/auth';

type AuditItem = {
  id: string;
  createdAt: string;
  action: string;
  canonicalAction: string;
  entity: string;
  canonicalEntity: string;
  entityId: string;
  actor?: { email?: string | null; role?: string | null } | null;
  metaJson?: Record<string, unknown> | null;
};

type AuditListResponse = {
  items: AuditItem[];
  total: number;
  take: number;
  skip: number;
};

async function api<T>(path: string): Promise<T> {
  const res = await fetch(path, { method: 'GET', cache: 'no-store' });
  if (!res.ok) {
    let msg = res.statusText;
    try {
      const body = await res.json();
      msg = body?.message || msg;
    } catch {}
    throw new Error(`${res.status} ${msg}`);
  }
  return (await res.json()) as T;
}

export default function AdminAuditPage() {
  const [allowed] = React.useState(() => requireRole(['ADMIN']));
  const [rows, setRows] = React.useState<AuditItem[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const [q, setQ] = React.useState('');
  const [action, setAction] = React.useState('');
  const [entityType, setEntityType] = React.useState('');
  const [from, setFrom] = React.useState('');
  const [to, setTo] = React.useState('');
  const [take, setTake] = React.useState(20);
  const [skip, setSkip] = React.useState(0);
  const [total, setTotal] = React.useState(0);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const p = new URLSearchParams();
      p.set('take', String(take));
      p.set('skip', String(skip));
      if (q.trim()) p.set('q', q.trim());
      if (action.trim()) p.set('action', action.trim());
      if (entityType.trim()) p.set('entityType', entityType.trim());
      if (from.trim()) p.set('from', from.trim());
      if (to.trim()) p.set('to', to.trim());
      const data = await api<AuditListResponse>(`/api/admin/audit?${p.toString()}`);
      setRows(Array.isArray(data.items) ? data.items : []);
      setTotal(Number(data.total || 0));
    } catch (e: any) {
      setError(e?.message || 'Denetim kayıtları alınamadı');
    } finally {
      setLoading(false);
    }
  }, [action, entityType, from, q, skip, take, to]);

  React.useEffect(() => {
    if (!allowed) return;
    load();
  }, [allowed, load]);

  if (!allowed) {
    return (
      <main style={{ padding: 24, maxWidth: 960, margin: '0 auto', opacity: 0.8 }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  const page = Math.floor(skip / take) + 1;
  const totalPages = Math.max(1, Math.ceil(total / take));

  return (
    <RoleShell
      role="ADMIN"
      title="Denetim Kayıtları"
      subtitle="Sistem aksiyonlarını ham + kanonik alanlarla izle."
      nav={[
        { href: '/admin', label: 'Panel' },
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/audit', label: 'Denetim' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
      ]}
    >
      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
        <input
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setSkip(0);
          }}
          placeholder="Ara: entityId, actor email, action..."
          style={{ padding: 10, borderRadius: 10, border: '1px solid #ddd', minWidth: 260 }}
        />
        <input
          value={action}
          onChange={(e) => {
            setAction(e.target.value);
            setSkip(0);
          }}
          placeholder="Action filtresi"
          style={{ padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
        />
        <input
          value={entityType}
          onChange={(e) => {
            setEntityType(e.target.value);
            setSkip(0);
          }}
          placeholder="Entity filtresi"
          style={{ padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
        />
        <input
          value={from}
          onChange={(e) => {
            setFrom(e.target.value);
            setSkip(0);
          }}
          placeholder="from (ISO)"
          style={{ padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
        />
        <input
          value={to}
          onChange={(e) => {
            setTo(e.target.value);
            setSkip(0);
          }}
          placeholder="to (ISO)"
          style={{ padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
        />
        <select
          value={String(take)}
          onChange={(e) => {
            setTake(Number(e.target.value));
            setSkip(0);
          }}
          style={{ padding: 10, borderRadius: 10, border: '1px solid #ddd', background: '#fff' }}
        >
          <option value="20">20</option>
          <option value="50">50</option>
          <option value="100">100</option>
        </select>
        <button onClick={load} style={{ padding: '10px 12px', borderRadius: 10, border: '1px solid #ddd', background: '#fff' }} disabled={loading}>
          Yenile
        </button>
        <button
          onClick={() => {
            setQ('');
            setAction('');
            setEntityType('');
            setFrom('');
            setTo('');
            setSkip(0);
          }}
          style={{ padding: '10px 12px', borderRadius: 10, border: '1px solid #ddd', background: '#fff' }}
          type="button"
        >
          Filtreyi Sıfırla
        </button>
      </div>

      {error ? <AlertMessage type="error" message={error} /> : null}

      <div style={{ marginTop: 12, fontSize: 13, color: '#666' }}>
        Toplam: <b>{total}</b> | Sayfa: <b>{page}</b>/<b>{totalPages}</b>
      </div>

      <div style={{ marginTop: 12, border: '1px solid #eee', borderRadius: 14, overflow: 'hidden' }}>
        <div style={{ padding: 12, borderBottom: '1px solid #eee', background: '#fafafa', fontWeight: 600 }}>
          {loading ? 'Yükleniyor…' : `${rows.length} kayıt`}
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 920 }}>
            <thead>
              <tr style={{ textAlign: 'left' }}>
                <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Tarih</th>
                <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Action</th>
                <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Canonical Action</th>
                <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Entity</th>
                <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Canonical Entity</th>
                <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Entity ID</th>
                <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Actor</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td style={{ padding: 12, borderBottom: '1px solid #f3f3f3', whiteSpace: 'nowrap' }}>{new Date(r.createdAt).toLocaleString()}</td>
                  <td style={{ padding: 12, borderBottom: '1px solid #f3f3f3' }}>{r.action}</td>
                  <td style={{ padding: 12, borderBottom: '1px solid #f3f3f3' }}>{r.canonicalAction}</td>
                  <td style={{ padding: 12, borderBottom: '1px solid #f3f3f3' }}>{r.entity}</td>
                  <td style={{ padding: 12, borderBottom: '1px solid #f3f3f3' }}>{r.canonicalEntity}</td>
                  <td style={{ padding: 12, borderBottom: '1px solid #f3f3f3' }}>
                    <code>{r.entityId}</code>
                  </td>
                  <td style={{ padding: 12, borderBottom: '1px solid #f3f3f3' }}>{r.actor?.email || r.actor?.role || '-'}</td>
                </tr>
              ))}
              {!loading && rows.length === 0 && (
                <tr>
                  <td colSpan={7} style={{ padding: 16, color: '#666' }}>
                    Kayıt bulunamadı.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div style={{ marginTop: 12, display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
        <button
          onClick={() => setSkip((s) => Math.max(s - take, 0))}
          disabled={loading || skip <= 0}
          style={{ padding: '8px 12px', borderRadius: 10, border: '1px solid #ddd', background: '#fff' }}
        >
          Önceki
        </button>
        <button
          onClick={() => setSkip((s) => s + take)}
          disabled={loading || skip + take >= total}
          style={{ padding: '8px 12px', borderRadius: 10, border: '1px solid #ddd', background: '#fff' }}
        >
          Sonraki
        </button>
      </div>
    </RoleShell>
  );
}
