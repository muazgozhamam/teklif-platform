#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DASH="$ROOT/apps/dashboard"

ROLE_ROUTE="$DASH/app/api/admin/users/[id]/role/route.ts"
USERS_ROUTE="$DASH/app/api/admin/users/route.ts"

echo "==> ROOT=$ROOT"
echo "==> DASH=$DASH"

if [ ! -f "$ROLE_ROUTE" ]; then
  echo "HATA: bulunamadı: $ROLE_ROUTE"
  exit 1
fi
if [ ! -f "$USERS_ROUTE" ]; then
  echo "HATA: bulunamadı: $USERS_ROUTE"
  exit 1
fi

echo "==> Patch route handlers (NextRequest + params Promise)"

cat > "$USERS_ROUTE" <<'TS'
import { NextRequest } from 'next/server';
import { proxyToApi } from '@/lib/proxy';

export async function GET(req: NextRequest) {
  return proxyToApi(req, '/admin/users');
}
TS

cat > "$ROLE_ROUTE" <<'TS'
import { NextRequest } from 'next/server';
import { proxyToApi } from '@/lib/proxy';

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  return proxyToApi(req, `/admin/users/${id}/role`);
}
TS

echo "OK: rewritten:"
echo " - $USERS_ROUTE"
echo " - $ROLE_ROUTE"

echo
echo "==> Build dashboard to verify"
cd "$DASH"
pnpm -s build

echo
echo "DONE."
echo "Root build:"
echo "  cd $ROOT && pnpm -s build"
