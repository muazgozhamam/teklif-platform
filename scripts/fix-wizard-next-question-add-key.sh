#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/apps/api/src/leads/leads.service.ts"

if [ ! -f "$FILE" ]; then
  echo "❌ leads.service.ts bulunamadı"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8")
orig = txt

# field: xxx dönen object literal’ı yakala ve key ekle
# Örn:
# return { done:false, field, question }
pattern = re.compile(
    r"return\s*\{\s*([^}]*?)\bfield\s*:\s*([a-zA-Z0-9_]+)\s*,",
    re.S
)

def repl(m):
    before = m.group(1)
    field_var = m.group(2)
    return f"return {{ {before}key: {field_var}, field: {field_var},"

new_txt, n = pattern.subn(repl, txt)

if n == 0:
    raise SystemExit("❌ next-question return obj içinde field bulunamadı")

bak = p.with_suffix(".addkey.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ wizard next-question response'una key eklendi")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Build API"
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Done."
