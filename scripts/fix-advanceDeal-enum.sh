#!/usr/bin/env bash
set -e

ROOT_DIR="$(pwd)"
API_DIR="$ROOT_DIR/apps/api"
FILE="$API_DIR/src/deals/deals.service.ts"

echo "==> Patching advanceDeal to use DealStatus enum"

node <<'NODE'
const fs = require('fs');

const file = process.env.FILE || 'apps/api/src/deals/deals.service.ts';
let src = fs.readFileSync(file, 'utf8');

// 1) import DealStatus ekle
if (!src.includes('DealStatus')) {
  src = src.replace(
    /import\s+\{([^}]+)\}\s+from\s+'@prisma\/client';/,
    (m, g1) => `import { ${g1.trim()}, DealStatus } from '@prisma/client';`
  );
}

// 2) advanceDeal içindeki status: "READY" düzelt
src = src.replace(
  /status:\s*["']READY["']/g,
  'status: DealStatus.READY'
);

// 3) status: event varsa enum'a bağla
src = src.replace(
  /status:\s*event/g,
  'status: DealStatus[event as keyof typeof DealStatus]'
);

fs.writeFileSync(file, src, 'utf8');
console.log('✅ advanceDeal enum patch applied');
NODE

echo "==> Build"
cd "$API_DIR"
pnpm -s build

echo "✅ DONE"
