#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.controller.ts"

python3 - <<'PY'
from pathlib import Path
p = Path("apps/api/src/leads/leads.controller.ts")
txt = p.read_text(encoding="utf-8")

# body: { text: string } -> body: { initialText: string }
txt = txt.replace("create(@Body() body: { text: string })", "create(@Body() body: { initialText: string })")

# this.leads.create(body.text) -> this.leads.create(body.initialText)
txt = txt.replace("return this.leads.create(body.text);", "return this.leads.create(body.initialText);")

p.write_text(txt, encoding="utf-8")
print("==> Patched leads.controller.ts to use initialText")
PY

echo "==> DONE. If pnpm start:dev is running, it should reload."
