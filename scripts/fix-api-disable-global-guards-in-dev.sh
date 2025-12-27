#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
MAIN="$ROOT/apps/api/src/main.ts"

if [ ! -f "$MAIN" ]; then
  echo "HATA: main.ts yok: $MAIN"
  exit 1
fi

echo "==> Backup"
cp "$MAIN" "$MAIN.bak.$(date +%s)"

echo "==> Patch: app.useGlobalGuards(...) dev'de kapansın"

node <<'NODE'
const fs = require('fs');
const p = process.cwd() + '/apps/api/src/main.ts';
let s = fs.readFileSync(p,'utf8');

const guardCallRe = /app\.useGlobalGuards\([\s\S]*?\);\s*/m;

if (!guardCallRe.test(s)) {
  console.log("UYARI: main.ts içinde app.useGlobalGuards(...) bulunamadı. (Yine de dosya değişmedi.)");
  process.exit(0);
}

s = s.replace(guardCallRe, (m) => {
  return `
  // DEV: auth bypass açıkken global guard'ları devre dışı bırak (prod'a dokunma)
  if (!(process.env.NODE_ENV !== 'production' && process.env.DEV_AUTH_BYPASS === '1')) {
${m.trim().split('\n').map(l => '    ' + l).join('\n')}
  }
`;
});

fs.writeFileSync(p, s);
console.log("OK: useGlobalGuards dev koşulu eklendi.");
NODE

echo "==> apps/api/.env: DEV_AUTH_BYPASS=1 garanti"
ENV="$ROOT/apps/api/.env"
touch "$ENV"
if ! grep -q "^DEV_AUTH_BYPASS=" "$ENV"; then
  printf "\nDEV_AUTH_BYPASS=1\n" >> "$ENV"
else
  perl -i -pe "s/^DEV_AUTH_BYPASS=.*/DEV_AUTH_BYPASS=1/" "$ENV"
fi

echo "==> OK. API'yi restart etmen lazım."
echo "Eğer API foreground çalışıyorsa Ctrl+C ile durdur, sonra:"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
