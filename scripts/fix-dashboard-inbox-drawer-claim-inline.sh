#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

needle = "await claim(selectedId);"
if needle not in orig:
    raise SystemExit("❌ Pattern not found: `await claim(selectedId);`")

replacement = (
    "try {\n"
    "            const r = await fetch(`${API_BASE}/deals/${selectedId}/assign-to-me`, {\n"
    "              method: 'POST',\n"
    "              headers: { 'x-user-id': userId },\n"
    "            });\n"
    "            if (!r.ok) {\n"
    "              const raw = await r.text().catch(() => '');\n"
    "              throw new Error(raw || `HTTP ${r.status}`);\n"
    "            }\n"
    "          } catch (err) {\n"
    "            console.error(err);\n"
    "          }\n"
    "          try { window.location.reload(); } catch {}\n"
)

new = orig.replace(needle, replacement, 1)

bak = p.with_suffix(p.suffix + ".drawer-claim-inline.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Inlined drawer claim: assign-to-me + reload (replaced await claim(selectedId))")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
