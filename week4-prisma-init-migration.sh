#!/usr/bin/env bash
set -euo pipefail

cd apps/api

echo "==> Where am I?"
pwd

echo
echo "==> prisma/migrations exists?"
ls -la prisma || true

echo
echo "==> Create initial migration if none exists"
if [ -d "prisma/migrations" ] && [ "$(ls -A prisma/migrations 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
  echo "OK: prisma/migrations already exists and not empty."
else
  echo "No migrations found. Creating initial migration: init"
  pnpm prisma migrate dev --name init
fi

echo
echo "==> prisma migrate status"
pnpm prisma migrate status

echo
echo "==> prisma generate"
pnpm prisma generate

echo
echo "==> Migrations list (first 10):"
ls -la prisma/migrations | head || true

echo "==> DONE"
