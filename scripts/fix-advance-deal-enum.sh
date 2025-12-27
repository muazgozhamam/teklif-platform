#!/usr/bin/env bash
set -e

ROOT_DIR="$(pwd)"
API_DIR="$ROOT_DIR/apps/api"
FILE="$API_DIR/src/deals/deals.service.ts"

echo "==> Fixing advanceDeal enum issue"

node <<'NODE'
const fs = require('fs');

const file = process.env.FILE || 'apps/api/src/deals/deals.service.ts';
let src = fs.readFileSync(file, 'utf8');

/**
 * 1) DealStatus importunu garanti et
 */
if (src.includes("from '@prisma/client'") && !src.includes('DealStatus')) {
  src = src.replace(
    /import\s+\{([^}]*)\}\s+from\s+'@prisma\/client';/,
    (m, p1) => `import { ${p1.trim()}, DealStatus } from '@prisma/client';`
  );
}

/**
 * 2) status: "READY" → DealStatus.READY
 */
src = src.replace(/status:\s*["']READY["']/g, 'status: DealStatus.READY');

/**
 * 3) status: event → enum map
 */
src = src.replace(
  /status:\s*event/g,
  'status: DealStatus[event as keyof typeof DealStatus]'
);

fs.writeFileSync(file, src, 'utf8');
console.log('✅ advanceDeal enum fixed');
NODE

echo "==> Build API"
cd "$API_DIR"
pnpm -s build

echo "✅ DONE"
