#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
CTRL="$API_DIR/src/leads/leads.controller.ts"

[ -f "$CTRL" ] || { echo "❌ Missing: $CTRL"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/leads.controller.ts")
txt = p.read_text(encoding="utf-8")

# 1) Constructor içinde LeadsService param adını bul
# Örn: constructor(private readonly leadsService: LeadsService) {}
# Örn: constructor(private service: LeadsService) {}
m = re.search(r"constructor\s*\(\s*([^\)]*)\)", txt, re.S)
param_block = m.group(1) if m else ""

name = None
m2 = re.search(r"\b(private|public|protected)\s+(readonly\s+)?(?P<name>[A-Za-z_]\w*)\s*:\s*LeadsService\b", param_block)
if m2:
    name = m2.group("name")

# 2) Eğer yoksa constructor'a leadsService ekle
if not name:
    # LeadsService import var mı?
    if "LeadsService" not in txt:
        # Çok düşük ihtimal ama yine de: leads.service import satırını eklemeye çalış
        lines = txt.splitlines()
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith("import "):
                insert_at = i + 1
        lines.insert(insert_at, "import { LeadsService } from './leads.service';")
        txt = "\n".join(lines) + "\n"

    # constructor var mı?
    if re.search(r"constructor\s*\(", txt):
        # constructor param listesine ekle
        def repl(m):
            inside = m.group(1).strip()
            add = "private readonly leadsService: LeadsService"
            if inside == "":
                return f"constructor({add})"
            return f"constructor({inside}, {add})"
        txt = re.sub(r"constructor\s*\(\s*([^\)]*)\)", repl, txt, count=1, flags=re.S)
    else:
        # class içine constructor ekle
        cm = re.search(r"export\s+class\s+LeadsController\s*{", txt)
        if not cm:
            raise SystemExit("LeadsController class not found")
        insert_pos = cm.end()
        txt = txt[:insert_pos] + "\n  constructor(private readonly leadsService: LeadsService) {}\n" + txt[insert_pos:]

    name = "leadsService"

# 3) this.leadsService -> this.<name>
txt = txt.replace("this.leadsService.", f"this.{name}.")

p.write_text(txt, encoding="utf-8")
print(f"✅ Patched LeadsController to use injected name: {name}")
PY

echo
echo "==> build apps/api"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
