#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"

echo "==> 0) Preconditions"
[ -d "$API_DIR/src" ] || { echo "ERROR: apps/api/src yok"; exit 1; }

echo "==> 1) Ensure DealsModule exists"
[ -f "$API_DIR/src/deals/deals.module.ts" ] || { echo "ERROR: src/deals/deals.module.ts yok"; exit 1; }
[ -f "$API_DIR/src/deals/deals.controller.ts" ] || { echo "ERROR: src/deals/deals.controller.ts yok"; exit 1; }
[ -f "$API_DIR/src/deals/deals.service.ts" ] || { echo "ERROR: src/deals/deals.service.ts yok"; exit 1; }

echo "==> 2) Ensure AppModule imports DealsModule"
APP_MODULE="$API_DIR/src/app.module.ts"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/app.module.ts")
s = p.read_text(encoding="utf-8")

if "DealsModule" not in s:
    # import ekle
    s = re.sub(r"(import\s+\{[^}]*\}\s+from\s+'@nestjs/common';\n)",
               r"\1import { DealsModule } from './deals/deals.module';\n", s, count=1)
    if "DealsModule" not in s:
        # fallback: dosyanın üst import bloğuna ekle
        s = "import { DealsModule } from './deals/deals.module';\n" + s

# imports array içine ekle (yoksa)
if re.search(r"imports\s*:\s*\[[^\]]*\bDealsModule\b", s, re.S) is None:
    s = re.sub(r"(imports\s*:\s*\[)",
               r"\1\n    DealsModule,", s, count=1)

p.write_text(s, encoding="utf-8")
print("OK: AppModule ensured DealsModule import")
PY

echo "==> 3) Prisma generate (Deal client fieldleri gelsin) + build"
cd "$API_DIR"

# ENV sorunu yaşamamak için migrate değil, generate + build yapıyoruz.
# DATABASE_URL resolve edilemezse, prisma.config.ts / .env tarafında problem vardır.
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build

echo
echo "==> 4) DONE"
echo "Şimdi DEV server'ı restart et (bu adımı script yapamaz):"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Server açılınca test:"
echo "  curl -i http://localhost:3001/health"
echo "  curl -i http://localhost:3001/docs"
echo "  curl -i http://localhost:3001/deals/by-lead/<LEAD_ID>"
