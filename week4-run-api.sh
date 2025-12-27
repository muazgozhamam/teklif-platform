#!/usr/bin/env bash
set -euo pipefail

cd apps/api

echo "==> apps/api scripts:"
node -e "const p=require('./package.json'); console.log(p.scripts||{});"

if node -e "const s=require('./package.json').scripts||{}; process.exit(s.dev?0:1)"; then
  echo "==> Running: pnpm run dev"
  pnpm run dev
elif node -e "const s=require('./package.json').scripts||{}; process.exit(s['start:dev']?0:1)"; then
  echo "==> Running: pnpm run start:dev"
  pnpm run start:dev
elif node -e "const s=require('./package.json').scripts||{}; process.exit(s.start?0:1)"; then
  echo "==> Running: pnpm run start"
  pnpm run start
else
  echo "HATA: dev/start:dev/start script yok. package.json scripts bölümünü buraya yapıştır."
  exit 1
fi
