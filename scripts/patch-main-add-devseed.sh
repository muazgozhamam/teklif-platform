#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
MAIN="$API_DIR/src/main.ts"

if [ ! -f "$MAIN" ]; then
  echo "HATA: main.ts yok: $MAIN"
  exit 1
fi

cp "$MAIN" "$MAIN.bak.$(date +%Y%m%d-%H%M%S)"
echo "✅ Backup alındı: $MAIN.bak.$(date +%Y%m%d-%H%M%S)"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/main.ts")
txt = p.read_text(encoding="utf-8")

# 1) DevSeedModule import ekle (yoksa)
if "DevSeedModule" not in txt:
    # AppModule importunu bulup altına ekle
    m = re.search(r"^import\s+\{\s*AppModule\s*\}\s+from\s+['\"]\.\/app\.module['\"];?\s*$", txt, flags=re.M)
    if not m:
        # AppModule importu farklı formda olabilir: import AppModule from ...
        m2 = re.search(r"^import\s+.*AppModule.*from\s+['\"]\.\/app\.module['\"];?\s*$", txt, flags=re.M)
        if not m2:
            raise SystemExit("❌ AppModule import satırı bulunamadı. main.ts çok farklı.")
        insert_at = m2.end()
    else:
        insert_at = m.end()

    txt = txt[:insert_at] + "\nimport { DevSeedModule } from './dev/dev-seed.module';\n" + txt[insert_at:]
    print("✅ DevSeedModule import eklendi.")
else:
    print("ℹ️ DevSeedModule import zaten var.")

# 2) isDev flag ekle (bootstrap içine)
if "const isDev =" not in txt:
    b = re.search(r"async function bootstrap\(\)\s*\{\s*", txt)
    if not b:
        raise SystemExit("❌ bootstrap() fonksiyonu bulunamadı.")
    txt = txt[:b.end()] + "  const isDev = process.env.NODE_ENV !== 'production';\n" + txt[b.end():]
    print("✅ isDev flag eklendi.")
else:
    print("ℹ️ isDev zaten var.")

# 3) NestFactory.create(...) veya createApplicationContext(...) içinde AppModule'u dev wrapper ile değiştir
# Hedef arg1: AppModule  =>  isDev ? { module: AppModule, imports: [DevSeedModule] } : AppModule

wrapper = "isDev ? { module: AppModule, imports: [DevSeedModule] } : AppModule"

patterns = [
    # NestFactory.create(AppModule
    r"(NestFactory\.(?:create|createApplicationContext)(?:<[^>]+>)?\(\s*)AppModule(\s*[,\)])",
]

patched = False
for pat in patterns:
    m = re.search(pat, txt)
    if m:
        txt = re.sub(pat, rf"\1{wrapper}\2", txt, count=1)
        patched = True
        print("✅ NestFactory.* çağrısında AppModule dev wrapper ile değiştirildi.")
        break

if not patched:
    # Bazı projeler `const app = await NestFactory.create(AppModule);` yerine farklı isim kullanabilir.
    # AppModule'un ilk argüman olduğu herhangi bir NestFactory.create(...) yakala.
    pat2 = r"(NestFactory\.(?:create|createApplicationContext)(?:<[^>]+>)?\(\s*)AppModule(\s*[,\)])"
    if re.search(pat2, txt):
        txt = re.sub(pat2, rf"\1{wrapper}\2", txt, count=1)
        patched = True
        print("✅ Alternatif pattern ile patch yapıldı.")
    else:
        raise SystemExit("❌ NestFactory.create(AppModule) veya createApplicationContext(AppModule) bulunamadı. main.ts çok farklı.")

p.write_text(txt, encoding="utf-8")
print("✅ main.ts yazıldı.")
PY

echo
echo "✅ Patch tamam."
echo "Sonraki adım:"
echo "  cd $API_DIR && pnpm -s build"
echo "  cd $ROOT && kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
