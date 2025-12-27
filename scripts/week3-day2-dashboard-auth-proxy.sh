#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
DASH="$ROOT/apps/dashboard"

if [ ! -d "$DASH" ]; then
  echo "HATA: apps/dashboard bulunamadı. Root'ta misin? ($ROOT)"
  exit 1
fi

APP_DIR="$DASH/src/app"
if [ ! -d "$APP_DIR" ]; then
  APP_DIR="$DASH/app"
fi
if [ ! -d "$APP_DIR" ]; then
  echo "HATA: Next App Router klasörü bulunamadı (src/app veya app)."
  exit 1
fi

mkdir -p "$APP_DIR/api/admin/users" "$APP_DIR/api/admin/users/[id]/role"
mkdir -p "$DASH/src/lib"

echo "==> Dashboard auth proxy route'ları yazılıyor"

# 1) Proxy helper (server-side)
cat > "$DASH/src/lib/proxy.ts" <<'TS'
import { cookies, headers } from 'next/headers';

function getApiBase() {
  // server-side: NEXT_PUBLIC_API_BASE_URL varsa onu da okuyabilir
  return process.env.API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001';
}

function extractTokenFromCookies(cookieHeader?: string) {
  // Yaygın cookie isimleri
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

  // Cookie forward (HttpOnly dahil)
  const cookieHeader = h.get('cookie') || cookies().toString();

  // Authorization forward: önce gelen request header, yoksa cookie’den türet
  let auth = h.get('authorization') || h.get('Authorization');
  if (!auth) {
    const token = extractTokenFromCookies(cookieHeader);
    if (token) {
      // Cookie'de "Bearer xxx" ise normalize et
      auth = token.toLowerCase().startsWith('bearer ') ? token : `Bearer ${token}`;
    }
  }

  const init: RequestInit = {
    method: req.method,
    // Body: GET/HEAD harici forward
    body: (req.method === 'GET' || req.method === 'HEAD') ? undefined : await req.text(),
    headers: {
      'Content-Type': 'application/json',
      ...(cookieHeader ? { cookie: cookieHeader } : {}),
      ...(auth ? { Authorization: auth } : {}),
    },
    cache: 'no-store',
  };

  const upstream = await fetch(`${apiBase}${apiPath}`, init);

  const text = await upstream.text();
  return new Response(text, {
    status: upstream.status,
    headers: {
      'Content-Type': upstream.headers.get('content-type') || 'application/json',
    },
  });
}
TS

# 2) GET /api/admin/users
cat > "$APP_DIR/api/admin/users/route.ts" <<'TS'
import { proxyToApi } from '@/lib/proxy';

export async function GET(req: Request) {
  return proxyToApi(req, '/admin/users');
}
TS

# 3) PATCH /api/admin/users/:id/role
cat > "$APP_DIR/api/admin/users/[id]/role/route.ts" <<'TS'
import { proxyToApi } from '@/lib/proxy';

export async function PATCH(req: Request, ctx: { params: { id: string } }) {
  const { id } = ctx.params;
  return proxyToApi(req, `/admin/users/${id}/role`);
}
TS

echo "==> Admin Users client component proxy endpointlere yönlendiriliyor"

# 4) Admin users component'ini proxy'ye çevir
FEATURE="$DASH/src/features/admin/admin-users.tsx"
if [ -f "$FEATURE" ]; then
  # /admin/users -> /api/admin/users
  perl -0777 -i -pe "s|api<AdminUser\\[]>\\('/admin/users'\\)|api<AdminUser[]>('/api/admin/users')|g" "$FEATURE"
  # PATCH /admin/users/:id/role -> /api/admin/users/:id/role
  perl -0777 -i -pe "s|api\\(`\\/admin\\/users\\/\\$\\{userId\\}\\/role`|api(`/api/admin/users/${userId}/role`|g" "$FEATURE"
  # API helper importu kalabilir ama artık BASE'e ihtiyaç yok; yine de sorun değil.
else
  echo "UYARI: $FEATURE bulunamadı. Admin Users component yolunu kontrol et."
fi

# 5) api.ts: API_BASE fallback kalsın, proxy kullanınca önemli değil. Değiştirmiyorum.

# 6) .env.local: API_BASE_URL ekle (yoksa)
ENV_LOCAL="$DASH/.env.local"
if [ ! -f "$ENV_LOCAL" ]; then
  cat > "$ENV_LOCAL" <<'ENV'
# Server-side proxy API base
API_BASE_URL=http://localhost:3001
# (opsiyonel) Client-side doğrudan istersen:
# NEXT_PUBLIC_API_BASE_URL=http://localhost:3001
ENV
else
  if ! grep -q "^API_BASE_URL=" "$ENV_LOCAL"; then
    printf "\nAPI_BASE_URL=http://localhost:3001\n" >> "$ENV_LOCAL"
  fi
fi

echo "==> OK: Dashboard auth proxy kuruldu."
echo "Not: Token/cookie varsa Next proxy bunu API'ye Authorization olarak forward eder."
echo "Devam: pnpm dev (dashboard) + login olup /admin/users aç."
