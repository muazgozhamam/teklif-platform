#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
DASH="$ROOT/apps/dashboard"

if [ ! -d "$DASH" ]; then
  echo "HATA: apps/dashboard bulunamadı."
  exit 1
fi

APP_DIR="$DASH/src/app"
if [ ! -d "$APP_DIR" ]; then APP_DIR="$DASH/app"; fi
if [ ! -d "$APP_DIR" ]; then
  echo "HATA: Next App Router dizini yok (src/app veya app)."
  exit 1
fi

mkdir -p "$APP_DIR/admin/users"

cat > "$APP_DIR/admin/users/page.tsx" <<'TSX'
'use client';

import React from 'react';

type Role = 'USER' | 'BROKER' | 'ADMIN';

type AdminUser = {
  id: string;
  email: string;
  name: string | null;
  role: Role | string;
  invitedById?: string | null;
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
  const [loading, setLoading] = React.useState(true);
  const [savingId, setSavingId] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const data = await api<AdminUser[]>('/api/admin/users');
      setRows(data);
    } catch (e: any) {
      setError(e?.message || 'Yükleme hatası');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => {
    load();
  }, []);

  async function setRole(userId: string, role: Role) {
    setSavingId(userId);
    setError(null);

    const prev = rows;
    setRows(prev.map(r => (r.id === userId ? { ...r, role } : r)));

    try {
      await api(`/api/admin/users/${userId}/role`, {
        method: 'PATCH',
        body: JSON.stringify({ role }),
      });
    } catch (e: any) {
      setRows(prev);
      setError(e?.message || 'Kaydetme hatası');
    } finally {
      setSavingId(null);
    }
  }

  return (
    <div style={{ padding: 24, maxWidth: 1100, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0 }}>Admin Users</h1>
          <p style={{ margin: '6px 0 0', opacity: 0.75 }}>Kullanıcıları listele ve rol güncelle.</p>
        </div>
        <button
          onClick={load}
          style={{ padding: '10px 14px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
          disabled={loading}
        >
          Yenile
        </button>
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
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Email</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>İsim</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Role</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Created</th>
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
                    onChange={(e) => setRole(u.id, e.target.value as Role)}
                    disabled={savingId === u.id}
                    style={{ padding: '8px 10px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
                  >
                    <option value="USER">USER</option>
                    <option value="BROKER">BROKER</option>
                    <option value="ADMIN">ADMIN</option>
                  </select>
                  {savingId === u.id && <span style={{ marginLeft: 10, opacity: 0.7 }}>Kaydediliyor…</span>}
                </td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>
                  {u.createdAt ? new Date(u.createdAt).toLocaleString() : '-'}
                </td>
              </tr>
            ))}
            {!loading && rows.length === 0 && (
              <tr>
                <td colSpan={4} style={{ padding: 16, opacity: 0.7 }}>
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
    </div>
  );
}
TSX

echo "==> OK: Route yazıldı -> $APP_DIR/admin/users/page.tsx"
echo "Şimdi tarayıcıda yenile: http://localhost:3002/admin/users"
