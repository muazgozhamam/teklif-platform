'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';

type Role = 'USER' | 'BROKER' | 'ADMIN' | 'CONSULTANT' | 'HUNTER';

type AdminUser = {
  id: string;
  email: string;
  name: string | null;
  role: Role | string;
  isActive: boolean;
  createdAt?: string;
};

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers || {}),
    },
    cache: 'no-store',
  });
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

export default function AdminUsersPage() {
  const [rows, setRows] = React.useState<AdminUser[]>([]);
  const [q, setQ] = React.useState('');
  const [loading, setLoading] = React.useState(true);
  const [savingId, setSavingId] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const qs = q.trim() ? `?q=${encodeURIComponent(q.trim())}` : '';
      const data = await api<AdminUser[]>(`/api/admin/users${qs}`);
      setRows(data);
    } catch (e: any) {
      setError(e?.message || 'Yükleme hatası');
    } finally {
      setLoading(false);
    }
  }, [q]);

  React.useEffect(() => {
    load();
  }, [load]);

  async function patchUser(userId: string, patch: { role?: Role; isActive?: boolean }) {
    setSavingId(userId);
    setError(null);

    const prev = rows;
    setRows(prev.map(r => (r.id === userId ? { ...r, ...patch } : r)));

    try {
      await api(`/api/admin/users/${userId}`, {
        method: 'PATCH',
        body: JSON.stringify(patch),
      });
    } catch (e: any) {
      setRows(prev);
      setError(e?.message || 'Kaydetme hatası');
    } finally {
      setSavingId(null);
    }
  }

  return (
    <RoleShell
      role="ADMIN"
      title="Yönetici Kullanıcıları"
      subtitle="Kullanıcıları listele ve rol güncelle."
      nav={[
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
      ]}
    >
      <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
        <button
          onClick={load}
          style={{ padding: '10px 14px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
          disabled={loading}
        >
          Yenile
        </button>
      </div>

      <div style={{ marginTop: 12 }}>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Email/isim ara..."
          style={{ width: 320, maxWidth: '100%', padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
        />
      </div>

      {error && (
        <div style={{ marginTop: 12, padding: 12, borderRadius: 12, background: '#fff5f5', border: '1px solid #ffd6d6' }}>
          <strong>Hata:</strong> {error}
        </div>
      )}

      <div style={{ marginTop: 16, border: '1px solid #eee', borderRadius: 14, overflow: 'hidden' }}>
        <div style={{ padding: 12, borderBottom: '1px solid #eee', background: '#fafafa', fontWeight: 600 }}>
          {loading ? 'Yükleniyor…' : `${rows.length} kullanıcı`}
        </div>

        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', background: 'white' }}>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>E-posta</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>İsim</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Rol</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Durum</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Oluşturulma</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(u => (
              <tr key={u.id}>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>{u.email}</td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>{u.name || '-'}</td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>
                  <select
                    value={(u.role as Role) || 'USER'}
                    onChange={(e) => patchUser(u.id, { role: e.target.value as Role })}
                    disabled={savingId === u.id}
                    style={{ padding: '8px 10px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
                  >
                    <option value="USER">Kullanıcı (USER)</option>
                    <option value="BROKER">Broker (BROKER)</option>
                    <option value="CONSULTANT">Danışman (CONSULTANT)</option>
                    <option value="HUNTER">Hunter (HUNTER)</option>
                    <option value="ADMIN">Yönetici (ADMIN)</option>
                  </select>
                  {savingId === u.id && <span style={{ marginLeft: 10, opacity: 0.7 }}>Kaydediliyor…</span>}
                </td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>
                  <label style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    <input
                      type="checkbox"
                      checked={Boolean(u.isActive)}
                      onChange={(e) => patchUser(u.id, { isActive: e.target.checked })}
                      disabled={savingId === u.id}
                    />
                    <span>{u.isActive ? 'Aktif' : 'Pasif'}</span>
                  </label>
                </td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>
                  {u.createdAt ? new Date(u.createdAt).toLocaleString() : '-'}
                </td>
              </tr>
            ))}
            {!loading && rows.length === 0 && (
              <tr>
                <td colSpan={5} style={{ padding: 16, opacity: 0.7 }}>
                  Kayıt yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <p style={{ marginTop: 12, opacity: 0.7 }}>
        Eğer 401 görürsen, login sonrası cookie/token adı proxy tarafından yakalanmıyor demektir; onu da bir sonraki script ile otomatik fixleyeceğim.
      </p>
    </RoleShell>
  );
}
