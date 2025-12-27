#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/main.ts"

if [ ! -f "$FILE" ]; then
  echo "main.ts not found at $FILE"
  exit 1
fi

# Backup
cp "$FILE" "$FILE.bak.$(date +%s)"

# If enableCors already exists, do nothing
if grep -q "enableCors" "$FILE"; then
  echo "enableCors already present in main.ts (no change)."
  exit 0
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/main.ts")
s = p.read_text(encoding="utf-8")

# Find app creation line
# typical: const app = await NestFactory.create(AppModule);
m = re.search(r"(const\s+app\s*=\s*await\s+NestFactory\.create\([^;]*\);\s*)", s)
if not m:
  raise SystemExit("Could not find NestFactory.create(...) line to insert enableCors under it.")

insert = m.group(1) + """
  app.enableCors({
    origin: [/^http:\\/\\/localhost:\\d+$/],
    credentials: true,
  });
"""

s2 = s[:m.start(1)] + insert + s[m.end(1):]
p.write_text(s2, encoding="utf-8")
print("CORS block inserted into main.ts")
PY

echo "Done. Restart API:"
echo "  cd apps/api && pnpm dev"
