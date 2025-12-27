#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DASH="$ROOT/apps/dashboard"

P1="$DASH/lib/proxy.ts"
P2="$DASH/src/lib/proxy.ts"

echo "==> ROOT=$ROOT"
echo "==> DASH=$DASH"

patch_one () {
  local P="$1"
  mkdir -p "$(dirname "$P")"

  cat > "$P" <<'TS'
import { NextRequest, NextResponse } from 'next/server';
import { headers, cookies } from 'next/headers';

function resolveApiBase() {
  return (process.env.NEXT_PUBLIC_API_URL || process.env.API_URL || '').replace(/\/+$/, '');
}

export async function proxyToApi(req: Request | NextRequest, path: string) {
  const apiBase = resolveApiBase();

  if (!apiBase) {
    return NextResponse.json(
      { message: 'API base url is missing (NEXT_PUBLIC_API_URL or API_URL)' },
      { status: 500 },
    );
  }

  // Next.js 16: headers()/cookies() async olabilir -> await ile güvene al
  const h = await headers();
  const c = await cookies();

  // Cookie forward (HttpOnly dahil)
  const cookieHeader = h.get('cookie') || c.toString();

  // Authorization forward: önce gelen request header, yoksa cookie’den türet
  const auth = h.get('authorization') || h.get('Authorization') || '';

  const url = `${apiBase}${path}`;

  // Incoming request body forward
  let body: any = undefined;
  const method = (req as any).method || 'GET';
  if (!['GET', 'HEAD'].includes(method)) {
    body = await (req as any).text();
  }

  const upstream = await fetch(url, {
    method,
    headers: {
      'content-type': (req as any).headers?.get?.('content-type') || 'application/json',
      ...(cookieHeader ? { cookie: cookieHeader } : {}),
      ...(auth ? { authorization: auth } : {}),
    },
    body: body && body.length ? body : undefined,
    cache: 'no-store',
  });

  const text = await upstream.text();

  // content-type'e göre response dön
  const ct = upstream.headers.get('content-type') || '';
  if (ct.includes('application/json')) {
    try {
      return NextResponse.json(JSON.parse(text || 'null'), { status: upstream.status });
    } catch {
      return NextResponse.json({ raw: text }, { status: upstream.status });
    }
  }

  return new NextResponse(text, { status: upstream.status });
}
TS

  echo "OK: rewritten -> $P"
}

# Her iki olası lokasyonu da patch'le (varsa ikisi de doğru olur)
patch_one "$P1"
patch_one "$P2"

echo
echo "==> Build dashboard to verify"
cd "$DASH"
pnpm -s build

echo
echo "DONE."
echo "Root build:"
echo "  cd $ROOT && pnpm -s build"
