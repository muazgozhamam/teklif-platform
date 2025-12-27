#!/usr/bin/env bash
set -e

echo "==> Bootstrap users (ADMIN + CONSULTANT)"

cd apps/api
pnpm ts-node scripts/bootstrap-users.ts

echo "✅ DONE"
