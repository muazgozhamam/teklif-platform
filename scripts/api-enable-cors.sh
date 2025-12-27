#!/usr/bin/env bash
set -euo pipefail

API_MAIN="apps/api/src/main.ts"

echo "==> CORS enable ediliyor: $API_MAIN"

python3 - <<'PY'
from pathlib import Path
p = Path("apps/api/src/main.ts")
txt = p.read_text(encoding="utf-8")

if "enableCors" in txt:
    print("ℹ️ CORS zaten var")
else:
    txt = txt.replace(
        "const app = await NestFactory.create(AppModule);",
        """const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: true,
    credentials: true,
  });
"""
    )
    p.write_text(txt, encoding="utf-8")
    print("✅ CORS eklendi")
PY
