#!/usr/bin/env bash
set -euo pipefail

LEAD_ID="${1:-}"
if [[ -z "$LEAD_ID" ]]; then
  echo "Usage: bash scripts/check-deal-by-lead-db-v2.sh <LEAD_ID>"
  exit 1
fi

API_DIR="$(pwd)/apps/api"

node -e "
process.chdir('$API_DIR');
const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();
(async () => {
  const deal = await p.deal.findFirst({
    where: { leadId: '$LEAD_ID' },
    select: { id:true,status:true,city:true,district:true,type:true,rooms:true,leadId:true,updatedAt:true,createdAt:true }
  });
  console.log(JSON.stringify(deal, null, 2));
  await p.\$disconnect();
})().catch(async (e)=>{ console.error(e); await p.\$disconnect(); process.exit(1); });
"
