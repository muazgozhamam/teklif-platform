#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"

echo "==> Patching $FILE"

python3 - <<'PY'
from pathlib import Path
p = Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8")

# Replace wrong "initialText: String" with "initialText"
txt2 = txt.replace("initialText: String", "initialText")

# If still missing (different formatting), do a more robust patch
if txt2 == txt:
    # try common wrong variants
    txt2 = txt
    txt2 = txt2.replace("initialText:String", "initialText")
    txt2 = txt2.replace("initialText:  String", "initialText")
    txt2 = txt2.replace("initialText : String", "initialText")

p.write_text(txt2, encoding="utf-8")
print("==> OK: Patched leads.service.ts")
PY

echo "==> DONE. If start:dev is running, Nest should reload automatically."
