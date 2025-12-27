#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"

if [ ! -d "$API_DIR/src" ]; then
  echo "HATA: apps/api/src bulunamadı: $API_DIR/src"
  exit 1
fi

mkdir -p "$API_DIR/src/dev"

# 1) DevSeedModule oluştur
cat > "$API_DIR/src/dev/dev-seed.module.ts" <<'TS'
import { Module, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

// DEV amaçlı: E2E match akışının "No consultant available" ile takılmaması için
// uygulama açılışında 1 consultant garanti eder.
// NOT: Production'da kesinlikle çalışmaz (main.ts içinden sadece dev'de import edilir).
@Module({
  providers: [PrismaService],
})
export class DevSeedModule implements OnModuleInit {
  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit() {
    const email = 'consultant1@test.com';

    // Consultant var mı?
    const existing = await this.prisma.user.findFirst({
      where: { role: 'CONSULTANT' },
      orderBy: { createdAt: 'asc' },
      select: { id: true, email: true, role: true },
    });

    if (existing) {
      console.log(`[DEV-SEED] Consultant exists: ${existing.id} ${existing.email} ${existing.role}`);
      return;
    }

    // Yoksa oluştur (auth hash zorunluysa ileride burayı UserService üzerinden yaparız)
    const created = await this.prisma.user.upsert({
      where: { email },
      update: { role: 'CONSULTANT' },
      create: {
        email,
        password: 'pass123',
        name: 'Consultant 1',
        role: 'CONSULTANT',
      },
      select: { id: true, email: true, role: true },
    });

    console.log(`[DEV-SEED] Consultant created: ${created.id} ${created.email} ${created.role}`);
  }
}
TS

# 2) main.ts patch: dev'de DevSeedModule'u AppModule imports'a ekle
MAIN="$API_DIR/src/main.ts"
if [ ! -f "$MAIN" ]; then
  echo "HATA: main.ts bulunamadı: $MAIN"
  exit 1
fi

cp "$MAIN" "$MAIN.bak.$(date +%Y%m%d-%H%M%S)"
echo "✅ Backup: $MAIN.bak.$(date +%Y%m%d-%H%M%S)"

python3 - <<'PY'
from pathlib import Path
import re

main_path = Path("apps/api/src/main.ts")
txt = main_path.read_text(encoding="utf-8")

# DevSeedModule import'u yoksa ekle
if "DevSeedModule" not in txt:
    # AppModule importunu bulup hemen altına eklemeye çalış
    # örn: import { AppModule } from './app.module';
    m = re.search(r"^import\s+\{\s*AppModule\s*\}\s+from\s+['\"]\.\/app\.module['\"];?\s*$", txt, flags=re.M)
    if not m:
        raise SystemExit("❌ main.ts içinde AppModule import satırı bulunamadı. Elle patch gerekebilir.")
    insert_at = m.end()
    txt = txt[:insert_at] + "\nimport { DevSeedModule } from './dev/dev-seed.module';\n" + txt[insert_at:]
    print("✅ main.ts: DevSeedModule import eklendi.")
else:
    print("ℹ️ main.ts: DevSeedModule import zaten var.")

# createNestApplication(AppModule) satırını bul, dev’de dynamic module wrapper ile değiştir
# Hedef: createNestApplication(isDev ? { module: AppModule, imports:[DevSeedModule] } : AppModule)
pattern = r"createNestApplication\(\s*AppModule\s*\)"
if re.search(pattern, txt):
    if "const isDev =" not in txt:
        # bootstrap içine isDev eklemek için: async function bootstrap() { -> hemen altına
        b = re.search(r"async function bootstrap\(\)\s*\{\s*", txt)
        if not b:
            raise SystemExit("❌ main.ts bootstrap fonksiyonu bulunamadı.")
        insert = "  const isDev = process.env.NODE_ENV !== 'production';\n"
        txt = txt[:b.end()] + insert + txt[b.end():]
        print("✅ main.ts: isDev flag eklendi.")

    # createNestApplication(AppModule) değiştir
    replacement = "createNestApplication(isDev ? { module: AppModule, imports: [DevSeedModule] } : AppModule)"
    txt2 = re.sub(pattern, replacement, txt, count=1)
    txt = txt2
    print("✅ main.ts: createNestApplication wrapper eklendi.")
else:
    # zaten patchlenmiş olabilir
    if "imports: [DevSeedModule]" in txt:
        print("ℹ️ main.ts: createNestApplication zaten DevSeedModule ile patchli.")
    else:
        raise SystemExit("❌ createNestApplication(AppModule) bulunamadı. main.ts farklı olabilir.")

main_path.write_text(txt, encoding="utf-8")
PY

echo
echo "✅ Dev consultant seed kuruldu."
echo "Şimdi build al:"
echo "  cd $API_DIR && pnpm -s build"
echo
echo "Sonra E2E:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
