#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

if [ ! -f "$ROOT/pnpm-workspace.yaml" ]; then
  echo "❌ Repo root bulunamadı (pnpm-workspace.yaml yok). ROOT=$ROOT"
  exit 1
fi

MAIN="$ROOT/apps/api/src/main.ts"
if [ ! -f "$MAIN" ]; then
  echo "❌ Missing: $MAIN"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/main.ts")
txt = p.read_text(encoding="utf-8")
orig = txt

# 1) Ensure ValidationPipe import
if "ValidationPipe" not in txt:
    # If there is already an import from '@nestjs/common', extend it; otherwise insert new import.
    m = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*'@nestjs/common'\s*;", txt)
    if m:
        items = [x.strip() for x in m.group(1).split(",") if x.strip()]
        if "ValidationPipe" not in items:
            items.append("ValidationPipe")
        new_line = "import { " + ", ".join(items) + " } from '@nestjs/common';"
        txt = txt[:m.start()] + new_line + txt[m.end():]
    else:
        # insert after first import line
        lines = txt.splitlines(True)
        insert_at = 1 if lines else 0
        lines.insert(insert_at, "import { ValidationPipe } from '@nestjs/common';\n")
        txt = "".join(lines)

# 2) Insert app.useGlobalPipes(...) after NestFactory.create
pipe_line = "  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: false }));\n"

if "useGlobalPipes(new ValidationPipe" not in txt:
    m2 = re.search(r"(\s*const\s+app\s*=\s*await\s+NestFactory\.create\(\s*AppModule\s*\)\s*;\s*\n)", txt)
    if not m2:
        raise SystemExit("❌ Could not find 'const app = await NestFactory.create(AppModule);' in main.ts")
    txt = txt[:m2.end(1)] + pipe_line + txt[m2.end(1):]

if txt == orig:
    raise SystemExit("❌ No changes applied (unexpected).")

bak = p.with_suffix(p.suffix + ".globalpipe.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Added global ValidationPipe with transform:true")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Build API (typecheck)"
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Done."
