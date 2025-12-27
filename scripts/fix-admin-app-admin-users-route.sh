#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

echo "==> @teklif/admin Next app aranıyor..."

# 1) apps altında name'i @teklif/admin olan paketi bul
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
  echo "HATA: apps/* altında name '@teklif/admin' olan package.json bulamadım."
  echo "Mevcut paket isimleri:"
  for d in "$ROOT"/apps/*; do
    if [ -f "$d/package.json" ]; then
      NAME="$(node -p "require('$d/package.json').name" 2>/dev/null || true)"
      echo " - $(basename "$d"): $NAME"
    fi
  done
  exit 1
fi

echo "OK: Admin Next app -> $APP_DIR"

# 2) App Router dizinini tespit et
APP_ROUTER="$APP_DIR/src/app"
if [ ! -d "$APP_ROUTER" ]; then APP_ROUTER="$APP_DIR/app"; fi
if [ ! -d "$APP_ROUTER" ]; then
  echo "HATA: App Router dizini yok (src/app veya app): $APP_DIR"
  exit 1
fi
echo "OK: App Router -> $APP_ROUTER"

# 3) Proxy helper + route handlers (Next server)
mkdir -p "$APP_DIR/src/lib"
mkdir -p "$APP_ROUTER/api/admin/users" "$APP_ROUTER/api/admin/users/[id]/role"
mkdir -p "$APP_ROUTER/admin/users"

cat > "$APP_DIR/src/lib/proxy.ts" <<'TS'
import { cookies, headers } from 'next/headers';

function getApiBase() {
  return process.env.API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001';
}

function extractTokenFromCookies(cookieHeader?: string) {
  const jar = cookieHeader || '';
  const candidates = ['access_token', 'token', 'jwt', 'Authorization'];
  for (const name of candidates) {
    const m = jar.match(new RegExp(`${name}=([^;]+)`));
    if (m?.[1]) return decodeURIComponent(m[1]);
  }
  return null;
}

export async function proxyToApi(req: Request, apiPath: string) {
  const apiBase = getApiBase();
  const h = headers();
  const cookieHeader = h.get('cookie') || cookies().toString();

  let auth = h.get('authorization') || h.get('Authorization');
  if (!auth) {
    const token = extractTokenFromCookies(cookieHeader);
    if (token) auth = token.toLowerCase().startsWith('bearer ') ? token : `Bearer ${token}`;
  }

  const upstream = await fetch(`${apiBase}${apiPath}`, {
    method: req.method,
    body: (req.method === 'GET' || req.method === 'HEAD') ? undefined : await req.text(),
    headers: {
      'Content-Type': 'application/json',
      ...(cookieHeader ? { cookie: cookieHeader } : {}),
      ...(auth ? { Authorization: auth } : {}),
    },
    cache: 'no-store',
  });

  const text = await upstream.text();
  return new Response(text, {
    status: upstream.status,
    headers: { 'Content-Type': upstream.headers.get('content-type') || 'application/json' },
  });
}
TS

cat > "$APP_ROUTER/api/admin/users/route.ts" <<'TS'
import { proxyToApi } from '@/lib/proxy';
export async function GET(req: Request) {
  return proxyToApi(req, '/admin/users');
}
TS

cat > "$APP_ROUTER/api/admin/users/[id]/role/route.ts" <<'TS'
import { proxyToApi } from '@/lib/proxy';
export async function PATCH(req: Request, ctx: { params: { id: string } }) {
  return proxyToApi(req, `/admin/users/${ctx.params.id}/role`);
}
TS

# 4) /admin/users page (self-contained, proxy'ye vurur)
cat > "$APP_ROUTER/admin/users/page.tsx" <<'TSX'
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
    headers: { 'Content-Type': 'application/json', ...(init?.headers || {}) },
    cache: 'no-store',
  });
  if (!res.ok) {
    let msg = res.statusText;
    try { const body = await res.json(); msg = body?.message || msg; } catch {}
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
    setLoading(true); setError(null);
    try {
      const data = await api<AdminUser[]>('/api/admin/users');
      setRows(data);
    } catch (e: any) {
      setError(e?.message || 'Yükleme hatası');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => { load(); }, []);

  async function setRole(userId: string, role: Role) {
    setSavingId(userId); setError(null);
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
        <button onClick={load} disabled={loading}
          style={{ padding: '10px 14px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}>
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
              <tr><td colSpan={4} style={{ padding: 16, opacity: 0.7 }}>Kayıt yok.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
TSX

# 5) .env.local içine API_BASE_URL ekle (admin app)
ENV_LOCAL="$APP_DIR/.env.local"
if [ ! -f "$ENV_LOCAL" ]; then
  echo "API_BASE_URL=http://localhost:3001" > "$ENV_LOCAL"
else
  if ! grep -q "^API_BASE_URL=" "$ENV_LOCAL"; then
    printf "\nAPI_BASE_URL=http://localhost:3001\n" >> "$ENV_LOCAL"
  fi
fi

echo "==> OK: @teklif/admin için /admin/users route + proxy eklendi."
echo "Tarayıcıda yenile: http://localhost:3002/admin/users"
