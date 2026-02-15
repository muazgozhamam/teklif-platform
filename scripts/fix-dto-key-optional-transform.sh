#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DTO="$ROOT/apps/api/src/leads/dto/lead-answer.dto.ts"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/dto/lead-answer.dto.ts")
txt = p.read_text(encoding="utf-8")
orig = txt

# 1) key alanını optional yap
txt = re.sub(r'(@IsString\(\)\s*@IsNotEmpty\(\)\s*)key\s*:\s*string\s*;',
             r'\1key?: string;',
             txt)

# 2) @Transform ekleyelim / güncelleyelim
# Eğer @Transform satırı yoksa ekle
if "@Transform" not in txt:
    txt = re.sub(r'(key\?\: string;)',
                 r'@Transform(({value,obj}) => value ?? obj?.field ?? "")\n\1',
                 txt)

if txt == orig:
    raise SystemExit("❌ No changes applied (already patched?)")

bak = p.with_suffix(".keyoptional.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Patched DTO: key optional + transform fallback field -> key")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Build API"
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Done."
