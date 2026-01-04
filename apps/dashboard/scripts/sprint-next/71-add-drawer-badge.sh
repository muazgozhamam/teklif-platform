#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="$ROOT/apps/dashboard/app/consultant/inbox/page.tsx"

echo "==> Add drawer badge"
echo "File: $FILE"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
txt = p.read_text(encoding="utf-8")

bak = p.with_suffix(p.suffix + ".drawerbadge71.bak")
bak.write_text(txt, encoding="utf-8")

old = re.compile(
    r"""<div style=\{\{ fontWeight: 900, fontSize: 15 \}\}>\s*
                \{\(selected\?\.\s*city.*?\}\s*
              </div>""",
    re.DOTALL
)

m = old.search(txt)
if not m:
    raise SystemExit("❌ Drawer title block not found. File may have changed.")

block = m.group(0)

new = """<div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
              <div style={{ fontWeight: 900, fontSize: 15 }}>
                {(selected?.city || '(no city)')}{selected?.district ? ` - ${selected.district}` : ''}
              </div>
              <span style={badgeStyle(getBadgeKind(selected))}>
                {getBadgeLabel(selected)}
              </span>
            </div>"""

txt2 = txt.replace(block, new)

p.write_text(txt2, encoding="utf-8")
print("✅ Drawer badge added.")
print("Backup:", bak)
PY

echo "✅ DONE"
