#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# Idempotent: if already exists, no-op
if re.search(r"\basync function\s+fetchDealById\s*\(", orig):
    raise SystemExit("✅ fetchDealById helper already exists (no change).")

helper = r"""

async function fetchDealById(dealId: string) {
  const id = String(dealId || '').trim();
  if (!id) throw new Error('Missing dealId');
  const r = await fetch(`${API_BASE}/deals/${id}`, { cache: 'no-store' });
  const raw = await r.text().catch(() => '');
  let json: any = null;
  try { json = raw ? JSON.parse(raw) : null; } catch {}
  if (!r.ok) {
    const msg = (json && (json.message || json.error)) || raw || `HTTP ${r.status}`;
    throw new Error(`fetchDealById ${r.status}: ${msg}`);
  }
  return (json || {}) as any;
}

"""

# Insert after API_BASE constant (stable anchor)
m = re.search(r"const\s+API_BASE\s*=\s*[\s\S]*?;\n", orig)
if not m:
    raise SystemExit("❌ Anchor not found: const API_BASE = ...;")

new = orig[:m.end()] + helper + orig[m.end():]

bak = p.with_suffix(p.suffix + ".add-fetchdealybyid.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Added top-level fetchDealById(dealId) helper")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
