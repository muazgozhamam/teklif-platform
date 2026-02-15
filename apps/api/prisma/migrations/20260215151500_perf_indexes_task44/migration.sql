-- TASK 4.4 performance indexes (backward-safe)
-- Keep index set minimal and query-driven.

-- Deal inbox/list patterns:
-- WHERE consultantId = ? ORDER BY createdAt DESC
CREATE INDEX IF NOT EXISTS "Deal_consultantId_createdAt_idx"
  ON "Deal" ("consultantId", "createdAt");

-- WHERE status = ? ORDER BY createdAt DESC
CREATE INDEX IF NOT EXISTS "Deal_status_createdAt_idx"
  ON "Deal" ("status", "createdAt");

-- Commission reports:
-- ORDER BY createdAt DESC with optional createdAt range filters.
CREATE INDEX IF NOT EXISTS "CommissionSnapshot_createdAt_idx"
  ON "CommissionSnapshot" ("createdAt");
