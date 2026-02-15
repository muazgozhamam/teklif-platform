#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"

if ! command -v psql >/dev/null 2>&1; then
  echo "HATA: psql bulunamadi"
  exit 2
fi

PSQL=(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X -q)

run_plan() {
  local title="$1"
  local sql="$2"
  echo
  echo "==> $title"
  local out
  out="$(${PSQL[@]} -c "EXPLAIN ${sql}")"
  echo "$out"
  if echo "$out" | grep -Eq 'Index Scan|Bitmap Index Scan|Index Only Scan'; then
    echo "OK index path detected"
  else
    echo "WARN index path not detected (check row counts / planner stats)"
  fi
}

# 1) Audit entity drilldown
run_plan \
  "Audit by entityType+entityId ordered by createdAt" \
  "SELECT id, \"createdAt\" FROM \"AuditLog\" WHERE \"entityType\"='DEAL' AND \"entityId\"='sample-deal-id' ORDER BY \"createdAt\" DESC LIMIT 50"

# 2) Audit action + time window
run_plan \
  "Audit by action+createdAt window" \
  "SELECT id FROM \"AuditLog\" WHERE \"action\" IN ('DEAL_STATUS_CHANGED','DEAL_ASSIGNED') AND \"createdAt\" >= NOW() - interval '30 day' ORDER BY \"createdAt\" DESC LIMIT 50"

# 3) Commission reports: consultant join + snapshot order
run_plan \
  "CommissionSnapshot join Deal by consultant + snapshot createdAt order" \
  "SELECT cs.id, cs.\"dealId\", cs.\"createdAt\" FROM \"CommissionSnapshot\" cs JOIN \"Deal\" d ON d.id = cs.\"dealId\" WHERE d.\"consultantId\"='sample-consultant-id' ORDER BY cs.\"createdAt\" DESC LIMIT 20"

# 4) Inbox pending
run_plan \
  "Deal pending inbox by status + createdAt" \
  "SELECT id, \"createdAt\" FROM \"Deal\" WHERE status='OPEN' AND \"consultantId\" IS NULL ORDER BY \"createdAt\" DESC LIMIT 20"

# 5) Inbox mine
run_plan \
  "Deal mine inbox by consultantId + createdAt" \
  "SELECT id, status, \"createdAt\" FROM \"Deal\" WHERE \"consultantId\"='sample-consultant-id' AND status IN ('OPEN','ASSIGNED','READY_FOR_LISTING','READY_FOR_MATCHING') ORDER BY \"createdAt\" DESC LIMIT 20"

echo

echo "OK diag-query-plans completed"
