#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_SRC="$ROOT/apps/api/src"
APP_MODULE="$API_SRC/app.module.ts"
APP_CONTROLLER="$API_SRC/app.controller.ts"
APP_SERVICE="$API_SRC/app.service.ts"

if [ ! -f "$APP_MODULE" ]; then
  echo "HATA: app.module.ts yok: $APP_MODULE"
  exit 1
fi

echo "==> 1) app.service.ts oluşturuluyor (yoksa)"
if [ ! -f "$APP_SERVICE" ]; then
cat > "$APP_SERVICE" <<'TS'
import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  health() {
    return { ok: true };
  }
}
TS
  echo "OK: $APP_SERVICE"
else
  echo "OK: $APP_SERVICE zaten var"
fi

echo "==> 2) app.controller.ts oluşturuluyor (yoksa)"
if [ ! -f "$APP_CONTROLLER" ]; then
cat > "$APP_CONTROLLER" <<'TS'
import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get('health')
  health() {
    return this.appService.health();
  }
}
TS
  echo "OK: $APP_CONTROLLER"
else
  echo "OK: $APP_CONTROLLER zaten var"
fi

echo "==> 3) app.module.ts: import/controllers/providers garanti ediliyor"
node <<'NODE'
const fs = require('fs');
const p = process.cwd() + '/apps/api/src/app.module.ts';
let s = fs.readFileSync(p, 'utf8');

function ensureImport(name, from) {
  const re = new RegExp(`import\\s*\\{[^}]*\\b${name}\\b[^}]*\\}\\s*from\\s*['"]${from}['"];?`);
  if (re.test(s)) return;

  // import bloğunun sonuna ekle
  const idx = s.lastIndexOf("import ");
  if (idx === -1) {
    s = `import { ${name} } from '${from}';\n` + s;
    return;
  }

  // importların bittiği yere ekle
  const importBlock = s.match(/^(import[\s\S]*?\n)\n/m);
  if (importBlock) {
    s = s.replace(importBlock[0], importBlock[0] + `import { ${name} } from '${from}';\n\n`);
  } else {
    s = `import { ${name} } from '${from}';\n` + s;
  }
}

ensureImport('AppController', './app.controller');
ensureImport('AppService', './app.service');

// @Module içindeki controllers/providers'a ekle
s = s.replace(/@Module\\(\\{([\\s\\S]*?)\\}\\)\\s*export\\s+class\\s+AppModule/m, (m, inner) => {
  let updated = inner;

  // controllers
  if (/controllers\\s*:\\s*\\[/.test(updated)) {
    if (!/AppController/.test(updated)) {
      updated = updated.replace(/controllers\\s*:\\s*\\[/, 'controllers: [AppController, ');
    }
  } else {
    updated = '  controllers: [AppController],\n' + updated;
  }

  // providers
  if (/providers\\s*:\\s*\\[/.test(updated)) {
    if (!/AppService/.test(updated)) {
      updated = updated.replace(/providers\\s*:\\s*\\[/, 'providers: [AppService, ');
    }
  } else {
    updated = '  providers: [AppService],\n' + updated;
  }

  return `@Module({${updated}})\nexport class AppModule`;
});

fs.writeFileSync(p, s);
console.log('OK: app.module.ts patched');
NODE

echo "==> 4) dist temizle (eski build kalıntısı karışmasın)"
rm -rf "$ROOT/apps/api/dist" 2>/dev/null || true

echo "==> OK: Eksik AppController/AppService düzeltildi."
echo "Şimdi API'yi yeniden başlat (dev komutunu yeniden çalıştır)."
