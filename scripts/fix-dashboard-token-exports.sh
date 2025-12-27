#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DASH="$ROOT/apps/dashboard"
LIB="$DASH/lib"

echo "==> ROOT=$ROOT"
echo "==> DASH=$DASH"

mkdir -p "$LIB"

echo "==> 1) Ensure lib/proxy.ts"
PROXY="$LIB/proxy.ts"
if [ ! -f "$PROXY" ]; then
cat > "$PROXY" <<'TS'
import { NextResponse } from 'next/server';

function getApiBase() {
  return process.env.API_BASE_URL
    || process.env.NEXT_PUBLIC_API_BASE_URL
    || 'http://localhost:3001';
}

export async function proxyToApi(req: Request, path: string) {
  const base = getApiBase();
  const url = new URL(req.url);
  const target = `${base}${path}${url.search ?? ''}`;

  const headers = new Headers(req.headers);
  headers.delete('host');

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
  return new NextResponse(res.body, { status: res.status, headers: res.headers });
}
TS
  echo "OK: created $PROXY"
else
  echo "OK: already exists $PROXY"
fi

echo
echo "==> 2) Patch lib/api.ts (add setToken/clearToken/getToken exports)"

# Prefer canonical path
API="$LIB/api.ts"

# If not found, try to locate an api.ts under dashboard
if [ ! -f "$API" ]; then
  echo "WARN: $API not found. Searching..."
  found="$(find "$DASH" -maxdepth 3 -type f -name "api.ts" | head -n 1 || true)"
  if [ -z "${found:-}" ]; then
    echo "HATA: dashboard içinde api.ts bulunamadı. Beklenen: $LIB/api.ts"
    exit 1
  fi
  API="$found"
  echo "OK: found api.ts -> $API"
else
  echo "OK: found -> $API"
fi

API_PATH="$API" node <<'NODE'
const fs = require('fs');

const apiPath = process.env.API_PATH;
if (!apiPath) {
  console.error('HATA: API_PATH env boş geldi');
  process.exit(1);
}

let s = fs.readFileSync(apiPath, 'utf8');

const hasSet = /export\s+(function|const)\s+setToken\b/.test(s);
const hasClear = /export\s+(function|const)\s+clearToken\b/.test(s);
const hasGet = /export\s+(function|const)\s+getToken\b/.test(s);

if (hasSet && hasClear && hasGet) {
  console.log('OK: lib/api.ts already has setToken/clearToken/getToken');
  process.exit(0);
}

const addon = `

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

if (!s.endsWith('\n')) s += '\n';
s += addon;

fs.writeFileSync(apiPath, s, 'utf8');
console.log('OK: appended token exports ->', apiPath);
NODE

echo
echo "==> 3) Build dashboard to verify"
cd "$DASH"
pnpm -s build

echo
echo "DONE."
echo "Root build:"
echo "  cd $ROOT && pnpm -s build"
