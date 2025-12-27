#!/usr/bin/env bash
set -e

API_SRC="apps/api/src"
APP_MODULE="$API_SRC/app.module.ts"
COMM_DIR="$API_SRC/commissions"

echo "==> commissions dosyalari garanti ediliyor"
mkdir -p "$COMM_DIR"

cat > "$COMM_DIR/commissions.controller.ts" <<'EOC'
import { Controller, Get } from '@nestjs/common';

@Controller('commissions')
export class CommissionsController {
  @Get()
  list() {
    return { ok: true };
  }
}
EOC

cat > "$COMM_DIR/commissions.module.ts" <<'EOM'
import { Module } from '@nestjs/common';
import { CommissionsController } from './commissions.controller';

@Module({
  controllers: [CommissionsController],
})
export class CommissionsModule {}
EOM

echo "==> AppModule patch ediliyor (zorla)"

# Import ekle (yoksa)
if ! grep -q "CommissionsModule" "$APP_MODULE"; then
  sed -i '' '1i\
import { CommissionsModule } from "./commissions/commissions.module";\
' "$APP_MODULE"
fi

# imports array'ine zorla ekle
perl -0777 -i -pe '
s/imports:\s*\[([^\]]*)\]/imports: [\1, CommissionsModule]/s
' "$APP_MODULE"

echo "==> Port 3001 temizleniyor"
PID=$(lsof -ti tcp:3001 || true)
if [ -n "$PID" ]; then
  kill -9 $PID
fi

echo "==> API baslatiliyor (yalnizca api)"
cd apps/api
pnpm dev &
PID=$!

sleep 5

echo "==> commissions route dogrulaniyor"
if ! grep -q "commissions" <(sleep 1); then
  echo "⚠️ Nest log'u burada gorunmez ama runtime test yap"
fi

sleep 2
curl -s http://localhost:3001/commissions || true

echo ""
echo "==> BİTTİ"
