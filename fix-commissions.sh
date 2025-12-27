#!/usr/bin/env bash
set -e

API_ROOT="apps/api/src"
COMM_DIR="$API_ROOT/commissions"
APP_MODULE="$API_ROOT/app.module.ts"

echo "==> commissions klasörü kontrol ediliyor"
mkdir -p "$COMM_DIR"

echo "==> commissions.controller.ts yazılıyor"
cat > "$COMM_DIR/commissions.controller.ts" <<'EOC'
import { Controller, Get } from '@nestjs/common';

@Controller('commissions')
export class CommissionsController {
  @Get()
  list() {
    return {
      ok: true,
      message: 'commissions endpoint aktif',
    };
  }
}
EOC

echo "==> commissions.module.ts yazılıyor"
cat > "$COMM_DIR/commissions.module.ts" <<'EOM'
import { Module } from '@nestjs/common';
import { CommissionsController } from './commissions.controller';

@Module({
  controllers: [CommissionsController],
})
export class CommissionsModule {}
EOM

echo "==> AppModule patch ediliyor"

# import yoksa ekle
if ! grep -q "CommissionsModule" "$APP_MODULE"; then
  perl -0777 -i -pe '
    s@(import .*?;\n)@$1import { CommissionsModule } from "./commissions/commissions.module";\n@s
  ' "$APP_MODULE"

  perl -0777 -i -pe '
    s@(imports:\s*\[)@$1\n    CommissionsModule,@s
  ' "$APP_MODULE"
else
  echo "==> AppModule zaten CommissionsModule içeriyor, geçildi"
fi

echo "==> TAMAM: commissions endpoint eklendi"
echo "==> Test: curl http://localhost:3001/commissions"
