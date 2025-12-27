#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

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
if [ ! -f "$API/src/main.ts" ]; then
  echo "HATA: apps/api/src/main.ts bulunamadı."
  exit 1
fi

echo "==> 1) Port/lock temizliği (3000-3003,3011)"
for PORT in 3000 3001 3002 3003 3011; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT -> $PIDS kill -9"
    kill -9 $PIDS || true
  fi
done
rm -f "$ROOT/apps/admin/.next/dev/lock" 2>/dev/null || true
rm -rf "$ROOT/apps/admin/.next" 2>/dev/null || true
rm -f "$ROOT/apps/dashboard/.next/dev/lock" 2>/dev/null || true
rm -rf "$ROOT/apps/dashboard/.next" 2>/dev/null || true
rm -rf "$ROOT/.turbo" 2>/dev/null || true

echo "==> 2) Admin proxy'yi harden et (try/catch -> 502 JSON)"
mkdir -p "$ADMIN_APP/src/lib"

cat > "$ADMIN_APP/src/lib/proxy.ts" <<'TS'
import { cookies, headers } from 'next/headers';

function getApiBase() {
  return process.env.API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3011';
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
    // fetch ECONNREFUSED vb. durumlarda Next 500 vermesin: 502 ile açık hata dön.
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

echo "==> 3) API main.ts: PORT env'e kesin bağla (default 3011)"
node <<'NODE'
const fs = require('fs');
const p = process.cwd() + '/apps/api/src/main.ts';
let s = fs.readFileSync(p,'utf8');

// await app.listen(...) satırını tek bir standarda çek
const re = /await\s+app\.listen\(([^)]+)\)\s*;/g;
if (re.test(s)) {
  s = s.replace(re, "await app.listen(Number(process.env.PORT ?? 3011));");
} else {
  // listen bulunamazsa dosyaya dokunmadan çık (riskli overwrite yapmayacağız)
  console.log("UYARI: main.ts içinde await app.listen(...) bulunamadı. Manuel kontrol gerekebilir.");
}
if (!s.includes("process.env.PORT ?? 3011")) {
  // Eğer replace olmadıysa yine de eklemeye çalışmayalım
} else {
  fs.writeFileSync(p, s);
  console.log("OK: main.ts listen patched -> PORT ?? 3011");
}
NODE

echo "==> 4) apps/api/.env: PORT=3011 + DEV_AUTH_BYPASS=1 garanti"
ENV_API="$API/.env"
touch "$ENV_API"
if ! grep -q "^PORT=" "$ENV_API"; then
  printf "\nPORT=3011\n" >> "$ENV_API"
else
  perl -i -pe "s/^PORT=.*/PORT=3011/" "$ENV_API"
fi
if ! grep -q "^DEV_AUTH_BYPASS=" "$ENV_API"; then
  printf "\nDEV_AUTH_BYPASS=1\n" >> "$ENV_API"
else
  perl -i -pe "s/^DEV_AUTH_BYPASS=.*/DEV_AUTH_BYPASS=1/" "$ENV_API"
fi

echo "==> 5) Admin .env.local: API_BASE_URL=http://localhost:3011 garanti"
ENV_ADMIN="$ADMIN_APP/.env.local"
touch "$ENV_ADMIN"
if ! grep -q "^API_BASE_URL=" "$ENV_ADMIN"; then
  printf "\nAPI_BASE_URL=http://localhost:3011\n" >> "$ENV_ADMIN"
else
  perl -i -pe "s#^API_BASE_URL=.*#API_BASE_URL=http://localhost:3011#" "$ENV_ADMIN"
fi

echo
echo "==> OK. Şimdi sadece API+ADMIN kaldır:"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
echo
echo "Admin Users sayfasında hata görürsen artık 500 değil, 502 JSON göreceksin (bağlantı teşhisi için)."
