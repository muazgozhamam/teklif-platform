#!/usr/bin/env bash
set -euo pipefail

API_DIR="apps/api"

cd "$API_DIR"

echo "==> Finding any existing user to use as createdById..."
USER_ID=$(pnpm exec prisma db execute --stdin <<'SQL' | tail -n 1 | tr -d '\r'
SELECT id FROM "User" ORDER BY "createdAt" DESC LIMIT 1;
SQL
)

if [ -z "$USER_ID" ] || [[ "$USER_ID" == *"id"* ]]; then
  echo "ERROR: User tablosunda kayıt bulamadım. Önce bir kullanıcı oluşturmalıyız."
  echo "Çözüm: /auth/register ile bir kullanıcı oluştur (sonra tekrar çalıştır)."
  exit 1
fi

echo "==> Using createdById: $USER_ID"

echo "==> Inserting Lead..."
pnpm exec prisma db execute --stdin <<SQL
INSERT INTO "Lead" (
  "id",
  "createdById",
  "category",
  "status",
  "title",
  "city",
  "district",
  "notes",
  "submittedAt",
  "createdAt",
  "updatedAt"
) VALUES (
  lower(hex(randomblob(16))),
  '$USER_ID',
  'KONUT',
  'PENDING_BROKER_APPROVAL',
  'Test Lead 1',
  'Konya',
  'Meram',
  'Week4-Day1 noauth seed',
  datetime('now'),
  datetime('now'),
  datetime('now')
);
SQL

echo "==> Latest Lead:"
pnpm exec prisma db execute --stdin <<'SQL'
SELECT id, status, title, city, district, createdById
FROM "Lead"
ORDER BY createdAt DESC
LIMIT 1;
SQL
