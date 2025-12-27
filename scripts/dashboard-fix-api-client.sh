#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DIR="$ROOT/apps/dashboard"
ENV_FILE="$DASH_DIR/.env.local"
API_FILE="$DASH_DIR/src/lib/api.ts"

echo "==> 1) .env.local içine NEXT_PUBLIC_API_BASE_URL yaz"
mkdir -p "$DASH_DIR"
if [[ -f "$ENV_FILE" ]]; then
  grep -v '^NEXT_PUBLIC_API_BASE_URL=' "$ENV_FILE" > "$ENV_FILE.tmp" || true
  mv "$ENV_FILE.tmp" "$ENV_FILE"
fi
echo "NEXT_PUBLIC_API_BASE_URL=http://localhost:3001" >> "$ENV_FILE"
echo "✅ $ENV_FILE:"
cat "$ENV_FILE"

echo
echo "==> 2) src/lib/api.ts base URL kullanıyor mu garanti et"
if [[ ! -f "$API_FILE" ]]; then
  echo "❌ $API_FILE bulunamadı. Dashboard yapısında farklı konum olabilir."
  echo "   Bulmak için: find apps/dashboard -maxdepth 5 -name api.ts"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
p = Path("apps/dashboard/src/lib/api.ts")
txt = p.read_text(encoding="utf-8")

# En güvenlisi: küçük, deterministik bir client yazıp dosyanın tamamını onunla değiştirmek.
fixed = """/* eslint-disable @typescript-eslint/no-explicit-any */

export function apiBase(): string {
  return (process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001').replace(/\\/+$/, '');
}

async function req<T = any>(path: string, init?: RequestInit): Promise<T> {
  const url = path.startsWith('http') ? path : `${apiBase()}${path}`;
  const res = await fetch(url, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers || {}),
    },
    cache: 'no-store',
  });

  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`HTTP ${res.status} ${res.statusText} - ${text}`);
  }

  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) return (await res.json()) as T;
  return (await res.text()) as any as T;
}

export const http = { req };
"""

p.write_text(fixed, encoding="utf-8")
print("✅ api.ts overwritten with deterministic base-url client:", p)
PY

echo
echo "✅ DONE."
echo "Şimdi dashboard'u restart etmen gerekiyor (env değişti):"
echo "  (dashboard terminalinde) CTRL+C"
echo "  cd $DASH_DIR && pnpm dev"
