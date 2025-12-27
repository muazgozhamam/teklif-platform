#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }

echo "==> 1) DB'den en son Deal id alınıyor"
DEAL_ID="$(node - <<'NODE'
const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();
(async () => {
  const d = await p.deal.findFirst({ orderBy: { createdAt: "desc" }, select: { id: true, status: true } });
  await p.$disconnect();
  if (!d) process.exit(2);
  console.log(d.id);
})().catch(async (e) => { console.error(e); process.exit(1); });
NODE
)" || true

if [ -z "${DEAL_ID}" ]; then
  echo "HATA: DB'de hiç Deal bulunamadı."
  echo "Önce Lead->Deal oluşturan endpoint'ini çalıştırmalıyız."
  exit 1
fi

echo "==> DEAL_ID=$DEAL_ID"

echo
echo "==> 2) advance: QUESTIONS_COMPLETED"
curl -s -X POST "http://localhost:3001/deals/${DEAL_ID}/advance" \
  -H "Content-Type: application/json" \
  -d '{"event":"QUESTIONS_COMPLETED"}' | node -e "process.stdin.on('data',d=>process.stdout.write(d))"

echo
echo
echo "==> DONE"
