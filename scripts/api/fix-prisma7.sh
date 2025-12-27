#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"

cd "$API_DIR"

echo "==> Prisma 7 uyumluluk düzeltmesi..."

# 1) schema.prisma içindeki url satırını kaldır (Prisma 7 gereği)
if grep -q "url *= *env(\"DATABASE_URL\"\)" prisma/schema.prisma; then
  perl -0777 -i -pe 's/\n\s*url\s*=\s*env\("DATABASE_URL"\)\s*\n/\n/gs' prisma/schema.prisma
  echo " - schema.prisma: datasource.url kaldırıldı"
else
  echo " - schema.prisma: datasource.url zaten yok"
fi

# 2) prisma.config.ts yaz / güncelle
cat > prisma.config.ts <<'TS'
import { defineConfig } from "prisma/config";

export default defineConfig({
  // Prisma 7: bağlantı URL'i migrate/db push/pull için burada olmalı
  datasource: {
    url: process.env.DATABASE_URL!,
  },
});
TS
echo " - prisma.config.ts güncellendi"

# 3) .env yoksa oluştur
if [ ! -f .env ]; then
  cat > .env <<'ENV'
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/emlak?schema=public"
PORT=3001
NODE_ENV=development
ENV
  echo " - .env oluşturuldu"
fi

echo "==> Prisma generate + db push çalıştırılıyor..."
npx prisma generate
npx prisma db push

echo "✅ Prisma 7 fix tamam."

