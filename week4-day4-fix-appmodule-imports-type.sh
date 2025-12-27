#!/usr/bin/env bash
set -euo pipefail

# bulunduğun dizine göre doğru yolu bulalım
if [ -f "apps/api/src/app.module.ts" ]; then
  APP="apps/api/src/app.module.ts"
elif [ -f "src/app.module.ts" ]; then
  APP="src/app.module.ts"
else
  echo "ERROR: app.module.ts bulunamadı (apps/api/src/app.module.ts veya src/app.module.ts)."
  exit 1
fi

echo "==> Fixing imports typing in: $APP"

python3 - <<PY
import re, pathlib
p = pathlib.Path("$APP")
s = p.read_text(encoding="utf-8")

orig = s

# 1) "const imports: string[] = [...]" veya benzeri tipleri any[] yap
s = re.sub(r":\s*string\[\]\s*=\s*\[", ": any[] = [", s)

# 2) "as string[]" castlerini kaldır (imports array'e yapışık olan)
s = re.sub(r"\]\s*as\s*string\[\]", "]", s)

# 3) "@Module({ imports: [...] as string[] })" gibi inline cast varsa temizle
s = re.sub(r"imports\s*:\s*\[([\s\S]*?)\]\s*as\s*string\[\]", r"imports: [\1]", s)

# 4) çok spesifik bir case: "imports: someVar as string[]"
s = re.sub(r"imports\s*:\s*([A-Za-z0-9_]+)\s*as\s*string\[\]", r"imports: \1", s)

if s == orig:
  print("No changes detected. app.module.ts içinde farklı bir tipleme olabilir.")
else:
  p.write_text(s, encoding="utf-8")
  print("Patched app.module.ts successfully.")
PY

echo "==> DONE"
