#!/usr/bin/env bash
set -e

API=apps/api/src

echo "==> Prisma TransactionClient typelaniyor"

FILES=$(grep -rl "\\$transaction(async (tx)" $API)

for f in $FILES; do
  perl -0777 -i -pe '
    s/async \(tx\)/async (tx: Prisma.TransactionClient)/g;
    s/import \{ PrismaService \} from/import { Prisma, PrismaService } from/g
  ' "$f"
done

echo "==> tx any HATASI COZULDU"
