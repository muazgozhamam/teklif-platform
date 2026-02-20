'use client';

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { requireRole } from '@/lib/auth';
import { api } from '@/lib/api';

type HunterLead = {
  id: string;
  status: string;
  createdAt: string;
  initialText?: string | null;
};

export default function HunterLeadsPage() {
  const [allowed, setAllowed] = React.useState(false);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [rows, setRows] = React.useState<HunterLead[]>([]);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<HunterLead[]>('/hunter/leads');
      setRows(Array.isArray(res.data) ? res.data : []);
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'message' in e
          ? String((e as { message?: string }).message || '')
          : '';
      setError(msg || 'Referans listesi alınamadı.');
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const ok = requireRole(['HUNTER']);
    setAllowed(ok);
    if (ok) load();
  }, [load]);

  if (!allowed) {
    return (
      <main style={{ padding: 24, maxWidth: 960, margin: '0 auto', opacity: 0.8 }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="HUNTER"
      title="Referanslarım"
      subtitle="Gönderdiğin referans kayıtlarını son durumlarıyla takip et."
      nav={[
        { href: '/hunter', label: 'Panel' },
        { href: '/hunter/leads', label: 'Referanslarım' },
        { href: '/hunter/leads/new', label: 'Yeni Referans' },
      ]}
    >
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
        <button
          type="button"
          onClick={load}
          disabled={loading}
          style={{
            padding: '9px 12px',
            borderRadius: 10,
            border: '1px solid #d7cfbf',
            background: '#fff',
            cursor: loading ? 'not-allowed' : 'pointer',
          }}
        >
          Yenile
        </button>
      </div>

      {error ? <AlertMessage type="error" message={error} /> : null}

      <div style={{ border: '1px solid #e2dbd1', borderRadius: 14, overflow: 'hidden', background: '#fff' }}>
        <div style={{ padding: 12, borderBottom: '1px solid #efe9df', fontWeight: 700 }}>
          {loading ? 'Yükleniyor…' : `${rows.length} referans`}
        </div>

        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left' }}>
              <th style={{ padding: 12, borderBottom: '1px solid #f2eee7' }}>Referans ID</th>
              <th style={{ padding: 12, borderBottom: '1px solid #f2eee7' }}>Durum</th>
              <th style={{ padding: 12, borderBottom: '1px solid #f2eee7' }}>Tarih</th>
              <th style={{ padding: 12, borderBottom: '1px solid #f2eee7' }}>Özet</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td style={{ padding: 12, borderBottom: '1px solid #f8f6f2' }}>
                  <code>{r.id}</code>
                </td>
                <td style={{ padding: 12, borderBottom: '1px solid #f8f6f2' }}>{r.status}</td>
                <td style={{ padding: 12, borderBottom: '1px solid #f8f6f2' }}>{new Date(r.createdAt).toLocaleString()}</td>
                <td style={{ padding: 12, borderBottom: '1px solid #f8f6f2' }}>{String(r.initialText || '').slice(0, 80) || '-'}</td>
              </tr>
            ))}
            {!loading && rows.length === 0 ? (
              <tr>
                <td colSpan={4} style={{ padding: 16, color: '#6f665c' }}>
                  Henüz referans kaydın yok. Yeni referans oluşturabilirsin.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </RoleShell>
  );
}
