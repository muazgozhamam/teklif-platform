#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

echo "==> Port temizliği (3000,3001,3002,3003)"
for PORT in 3000 3001 3002 3003; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT PID: $PIDS -> kill"
    kill $PIDS || true
    sleep 1
    PIDS2="$(lsof -ti tcp:$PORT || true)"
    if [ -n "$PIDS2" ]; then
      echo "Port $PORT PID: $PIDS2 -> kill -9"
      kill -9 $PIDS2 || true
    fi
  fi
done

echo "==> Next lock temizliği"
rm -f "$ROOT/apps/dashboard/.next/dev/lock" 2>/dev/null || true
rm -f "$ROOT/apps/admin/.next/dev/lock" 2>/dev/null || true

echo "==> turbo.json: dashboard dev task'ını dev'den çıkar (focus admin)"
TURBO="$ROOT/turbo.json"
if [ -f "$TURBO" ]; then
  node <<'NODE'
const fs=require('fs');
const p=process.cwd()+'/turbo.json';
const j=JSON.parse(fs.readFileSync(p,'utf8'));
j.tasks=j.tasks||{};

// dev task'ı genelde cache:false persistent:true
// Biz dashboard paketini turbo dev'de çalıştırmayacağız: "dependsOn" vs yoksa bile turbo zaten tüm dev tasklarını koşturuyor.
// Çözüm: dashboard package.json'da dev script'i kalsın ama root pnpm dev'de turbo sadece belirli filtrelerle çalıştırılacak.
fs.writeFileSync(p, JSON.stringify(j,null,2));
console.log('OK: turbo.json dokunulmadı (turbo filter ile çalıştıracağız).');
NODE
fi

echo
echo "==> Şimdi sadece api + admin başlat (dashboard hariç):"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
