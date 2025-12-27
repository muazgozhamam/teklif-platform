#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DASH="$ROOT/apps/dashboard"
LIB="$DASH/lib"
PROXY="$LIB/proxy.ts"
API="$LIB/api.ts"

echo "==> ROOT=$ROOT"
echo "==> DASH=$DASH"
mkdir -p "$LIB"

echo "==> 1) Ensure lib/proxy.ts"
if [ ! -f "$PROXY" ]; then
cat > "$PROXY" <<'TS'
import { NextResponse } from 'next/server';

function getApiBase() {
  // Prefer server-side env, fallback to localhost for dev
  return process.env.API_BASE_URL
    || process.env.NEXT_PUBLIC_API_BASE_URL
    || 'http://localhost:3001';
}

/**
 * Proxies an incoming Next Route Handler request to the API service.
 * Usage in routes:
 *   return proxyToApi(req, '/admin/users');
 */
export async function proxyToApi(req: Request, path: string) {
  const base = getApiBase();
  const url = new URL(req.url);

  // Keep querystring from incoming request
  const target = `${base}${path}${url.search ?? ''}`;

  // Forward headers (auth etc.)
  const headers = new Headers(req.headers);
  headers.delete('host');

  // If body exists, forward it (GET/HEAD must not include body)
  const method = req.method.toUpperCase();
  const init: RequestInit = { method, headers };

  if (method !== 'GET' && method !== 'HEAD') {
    const ct = req.headers.get('content-type') || '';
    if (ct.includes('application/json')) {
      init.body = JSON.stringify(await req.json().catch(() => ({})));
      headers.set('content-type', 'application/json');
    } else {
      init.body = await req.text();
    }
  }

  const res = await fetch(target, init);

  // Stream back response
  const resHeaders = new Headers(res.headers);
  return new NextResponse(res.body, {
    status: res.status,
    headers: resHeaders,
  });
}
TS
  echo "OK: created $PROXY"
else
  echo "OK: already exists $PROXY"
fi

echo
echo "==> 2) Ensure setToken/clearToken exports in lib/api.ts"
if [ ! -f "$API" ]; then
  echo "HATA: $API bulunamadı. Önce dosya var olmalı."
  exit 1
fi

node <<'NODE'
const fs = require('fs');

const apiPath = process.env.API_PATH;
let s = fs.readFileSync(apiPath, 'utf8');

// If already exports exist, do nothing
const hasSet = /export\s+(function|const)\s+setToken\b/.test(s);
const hasClear = /export\s+(function|const)\s+clearToken\b/.test(s);

// We'll add a small token store that is SSR-safe.
// Does not break existing `api` export—only appends missing exports.
if (!hasSet || !hasClear) {
  const addon = `\n
// ---- Added by script: token helpers (SSR-safe) ----
let __token: string | null = null;

export function setToken(token: string) {
  __token = token;
  if (typeof window !== 'undefined') {
    try { window.localStorage.setItem('teklif_token', token); } catch {}
  }
}

export function clearToken() {
  __token = null;
  if (typeof window !== 'undefined') {
    try { window.localStorage.removeItem('teklif_token'); } catch {}
  }
}

export function getToken() {
  if (__token) return __token;
  if (typeof window !== 'undefined') {
    try {
      const t = window.localStorage.getItem('teklif_token');
      __token = t;
      return t;
    } catch {}
  }
  return null;
}
// ---- end token helpers ----
`;

  // Ensure newline at end, then append
  if (!s.endsWith('\n')) s += '\n';
  s += addon;
  fs.writeFileSync(apiPath, s, 'utf8');
  console.log('OK: appended token exports to lib/api.ts');
} else {
  console.log('OK: lib/api.ts already has setToken/clearToken');
}
NODE
API_PATH="$API" node -e "process.exit(0)" >/dev/null 2>&1 || true

echo
echo "==> 3) Build dashboard to verify"
cd "$DASH"
pnpm -s build

echo
echo "DONE."
echo "Root build:"
echo "  cd $ROOT && pnpm -s build"
