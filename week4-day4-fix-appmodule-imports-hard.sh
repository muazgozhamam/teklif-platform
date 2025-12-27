#!/usr/bin/env bash
set -euo pipefail

APP="apps/api/src/app.module.ts"
if [ ! -f "$APP" ]; then
  echo "ERROR: $APP yok. Şu komutu çalıştır: ls -la apps/api/src | head"
  exit 1
fi

echo "==> Patching $APP"

python3 - <<'PY'
import re, pathlib
p = pathlib.Path("apps/api/src/app.module.ts")
s = p.read_text(encoding="utf-8")
orig = s

# 1) imports property: force "as any" (covers: ],  ] as string[],  ] as string[] , etc.)
s = re.sub(
  r"imports\s*:\s*\[([\s\S]*?)\]\s*(?:as\s*string\[\])?\s*,",
  r"imports: [\1] as any,\n",
  s,
  count=1
)

# 2) if there is a variable typed string[] like: const imports: string[] = [...]
s = re.sub(r":\s*string\[\]\s*=\s*\[", r": any[] = [", s)

# 3) remove stray casts "as string[]"
s = re.sub(r"\s+as\s+string\[\]", "", s)

if s == orig:
  print("No changes detected (structure farklı olabilir).")
else:
  p.write_text(s, encoding="utf-8")
  print("OK: patched.")
PY

echo "==> Show app.module.ts (first 60 lines)"
nl -ba "$APP" | sed -n '1,80p'
