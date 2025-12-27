#!/usr/bin/env bash
set -e

API_SRC="apps/api/src"
APP_MODULE="$API_SRC/app.module.ts"
COMM_CTRL="$API_SRC/commissions.controller.ts"

echo "==> CommissionsController yaziliyor (root level)"

cat > "$COMM_CTRL" <<'EOC'
import { Controller, Get } from '@nestjs/common';

@Controller('commissions')
export class CommissionsController {
  @Get()
  list() {
    return { ok: true, injected: true };
  }
}
EOC

echo "==> AppModule patch ediliyor (controllers injection)"

# import ekle
if ! grep -q "CommissionsController" "$APP_MODULE"; then
  sed -i '' '1i\
import { CommissionsController } from "./commissions.controller";\
' "$APP_MODULE"
fi

# controllers array yoksa oluştur, varsa ekle
if grep -q "controllers:" "$APP_MODULE"; then
  perl -0777 -i -pe '
    s/controllers:\s*\[([^\]]*)\]/controllers: [\1, CommissionsController]/s
  ' "$APP_MODULE"
else
  perl -0777 -i -pe '
    s/@Module\s*\(\s*\{/@Module({\n  controllers: [CommissionsController],/s
  ' "$APP_MODULE"
fi

echo "==> Port 3001 temizleniyor"
PID=$(lsof -ti tcp:3001 || true)
if [ -n "$PID" ]; then
  kill -9 $PID
fi

echo "==> API baslatiliyor"
cd apps/api
pnpm dev
