#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

# @teklif/admin app'i bul
ADMIN_APP=""
for d in "$ROOT"/apps/*; do
  if [ -f "$d/package.json" ]; then
    if node -e "const j=require('$d/package.json'); process.exit(j.name==='@teklif/admin'?0:1)"; then
      ADMIN_APP="$d"
      break
    fi
  fi
done

if [ -z "$ADMIN_APP" ]; then
  echo "HATA: @teklif/admin app bulunamadı."
  exit 1
fi

PROXY="$ADMIN_APP/src/lib/proxy.ts"
mkdir -p "$(dirname "$PROXY")"

echo "==> Overwrite: $PROXY (Next 16 await headers/cookies)"

cat > "$PROXY" <<'TS'
import { cookies, headers } from 'next/headers';

function getApiBase() {
  return process.env.API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3011';
}

function extractTokenFromCookieHeader(cookieHeader?: string) {
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

  // Next 16 "dynamic APIs" require awaiting in route handlers
  const h = await headers();
  const c = await cookies();

  // cookie header
  const cookieHeader = h.get('cookie') || c.toString();

  // auth header
  let auth = h.get('authorization') || h.get('Authorization');
  if (!auth) {
    const token = extractTokenFromCookieHeader(cookieHeader);
    if (token) auth = token.toLowerCase().startsWith('bearer ') ? token : `Bearer ${token}`;
  }

  const init: RequestInit = {
    method: req.method,
    body: (req.method === 'GET' || req.method === 'HEAD') ? undefined : await req.text(),
    headers: {
      'Content-Type': 'application/json',
      ...(cookieHeader ? { cookie: cookieHeader } : {}),
      ...(auth ? { Authorization: auth } : {}),
    },
    cache: 'no-store',
  };

  try {
    const upstream = await fetch(`${apiBase}${apiPath}`, init);
    const text = await upstream.text();

    return new Response(text, {
      status: upstream.status,
      headers: { 'Content-Type': upstream.headers.get('content-type') || 'application/json' },
    });
  } catch (err: any) {
    const payload = {
      message: 'Upstream API bağlantı hatası',
      apiBase,
      apiPath,
      error: String(err?.message || err),
    };
    return new Response(JSON.stringify(payload), {
      status: 502,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}
TS

echo "==> OK: proxy.ts Next16 uyumlu."
echo "Dev zaten watch modda; 10 sn sonra /admin/users yenile."
