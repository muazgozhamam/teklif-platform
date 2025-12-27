#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

# @teklif/admin app'i bul
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

mkdir -p "$APP_ROUTER/api/auth/login"

# Server route: /api/auth/login
cat > "$APP_ROUTER/api/auth/login/route.ts" <<'TS'
import { NextResponse } from 'next/server';

function getApiBase() {
  return process.env.API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001';
}

export async function POST(req: Request) {
  const apiBase = getApiBase();
  const body = await req.text();

  const upstream = await fetch(`${apiBase}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body,
    cache: 'no-store',
  });

  const text = await upstream.text();
  let data: any = null;
  try { data = JSON.parse(text); } catch {}

  // token alanını yakala
  const token =
    data?.access_token ||
    data?.token ||
    data?.jwt ||
    (typeof data === 'string' ? data : null);

  // upstream hata ise aynen dön
  if (!upstream.ok) {
    return new NextResponse(text, {
      status: upstream.status,
      headers: { 'Content-Type': upstream.headers.get('content-type') || 'application/json' },
    });
  }

  const res = new NextResponse(text, {
    status: upstream.status,
    headers: { 'Content-Type': upstream.headers.get('content-type') || 'application/json' },
  });

  if (token) {
    // 3002 origin'e HttpOnly cookie yaz
    res.headers.append(
      'Set-Cookie',
      `access_token=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax`
    );
  }

  return res;
}
TS

echo "==> OK: /api/auth/login eklendi (token -> HttpOnly cookie access_token)."
echo "Sonraki adım: login ekranının isteğini /api/auth/login'e yönlendir."
