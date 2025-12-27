#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

# apps altında name'i @teklif/admin olan paketi bul
APP_DIR=""
for d in "$ROOT"/apps/*; do
  if [ -f "$d/package.json" ]; then
    if node -e "const j=require('$d/package.json'); process.exit(j.name==='@teklif/admin'?0:1)"; then
      APP_DIR="$d"
      break
    fi
  fi
done

if [ -z "$APP_DIR" ]; then
  echo "HATA: @teklif/admin app bulunamadı."
  exit 1
fi

APP_ROUTER="$APP_DIR/src/app"
if [ ! -d "$APP_ROUTER" ]; then APP_ROUTER="$APP_DIR/app"; fi
if [ ! -d "$APP_ROUTER" ]; then
  echo "HATA: App Router dizini yok (src/app veya app): $APP_DIR"
  exit 1
fi

PAGE="$APP_ROUTER/admin/users/page.tsx"
if [ ! -f "$PAGE" ]; then
  echo "HATA: Admin users page bulunamadı: $PAGE"
  exit 1
fi

echo "==> Patch: $PAGE (localStorage token -> Authorization header)"

cat > "$PAGE" <<'TSX'
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

function getStoredToken(): string | null {
  if (typeof window === 'undefined') return null;

  // yaygın anahtarlar
  const keys = ['access_token', 'token', 'jwt', 'Authorization'];
  for (const k of keys) {
    const v = window.localStorage.getItem(k);
    if (v && v.trim()) return v.trim();
  }
  return null;
}

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const token = getStoredToken();

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(init?.headers as any),
  };

  // Token varsa Authorization ekle
  if (token) {
    headers['Authorization'] = token.toLowerCase().startsWith('bearer ')
      ? token
      : `Bearer ${token}`;
  }

  const res = await fetch(path, {
    ...init,
    headers,
    // Cookie bazlı auth da varsa gelsin
    credentials: 'include',
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
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0 }}>Admin Users</h1>
          <p style={{ margin: '6px 0 0', opacity: 0.75 }}>Kullanıcıları listele ve rol güncelle.</p>
        </div>
        <button
          onClick={load}
          disabled={loading}
          style={{ padding: '10px 14px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
        >
          Yenile
        </button>
      </div>

      {error && (
        <div style={{ marginTop: 12, padding: 12, borderRadius: 12, background: '#fff5f5', border: '1px solid #ffd6d6' }}>
          <strong>Hata:</strong> {error}
          <div style={{ marginTop: 8, opacity: 0.8 }}>
            Not: Token localStorage’da değilse 401 normal. Login ekranın token’ı localStorage’a yazıyorsa otomatik düzelir.
          </div>
        </div>
      )}

      <div style={{ marginTop: 16, border: '1px solid #eee', borderRadius: 14, overflow: 'hidden' }}>
        <div style={{ padding: 12, borderBottom: '1px solid #eee', background: '#fafafa', fontWeight: 600 }}>
          {loading ? 'Yükleniyor…' : `${rows.length} kullanıcı`}
        </div>

        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left' }}>
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
    </div>
  );
}
TSX

echo "==> OK: Token forwarding eklendi. Tarayıcıda /admin/users yenile."
