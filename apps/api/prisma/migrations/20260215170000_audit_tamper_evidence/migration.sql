-- TASK 6.4 Audit tamper-evidence (backward-safe)

ALTER TABLE "AuditLog"
  ADD COLUMN IF NOT EXISTS "prevHash" TEXT,
  ADD COLUMN IF NOT EXISTS "hash" TEXT;

CREATE INDEX IF NOT EXISTS "AuditLog_hash_idx"
  ON "AuditLog" ("hash");
