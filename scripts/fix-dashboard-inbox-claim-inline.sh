#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

needle = "onClick={(e) => { e.stopPropagation(); claim(d.id); }}"
replacement = (
    "onClick={async (e) => { "
    "e.stopPropagation(); "
    "try { "
    "const r = await fetch(`${API_BASE}/deals/${d.id}/assign-to-me`, { method: 'POST', headers: { 'x-user-id': userId } }); "
    "if (!r.ok) { const raw = await r.text().catch(()=>''); throw new Error(raw || `HTTP ${r.status}`); } "
    "} catch (err) { console.error(err); } "
    "try { window.location.reload(); } catch {} "
    "}}"
)

new = orig.replace(needle, replacement, 1)
if new == orig:
    raise SystemExit("❌ Pattern not found: claim(d.id) onClick block")

bak = p.with_suffix(p.suffix + ".claim-inline.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Inlined claim(d.id) into onClick (assign-to-me + reload)")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
