#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
CTRL="apps/api/src/leads/leads.controller.ts"
SVC="apps/api/src/leads/leads.service.ts"

if [[ ! -f "$CTRL" ]]; then echo "❌ Missing: $CTRL"; exit 1; fi
if [[ ! -f "$SVC" ]]; then echo "❌ Missing: $SVC"; exit 1; fi

python3 - <<'PY'
import re, pathlib, sys

ctrl = pathlib.Path("apps/api/src/leads/leads.controller.ts")
svc  = pathlib.Path("apps/api/src/leads/leads.service.ts")

# --- 1) Controller: wizardAnswer -> pass key + answer
t = ctrl.read_text(encoding="utf-8")

# replace only the wizardAnswer call line
t2, n = re.subn(
  r"return\s+this\.leads\.wizardAnswer\(\s*id\s*,\s*body\?\.\s*answer\s*\)\s*;",
  "return this.leads.wizardAnswer(id, body?.key, body?.answer);",
  t
)
if n == 0:
  # fallback: any call wizardAnswer(id, body?.answer)
  t2, n = re.subn(
    r"this\.leads\.wizardAnswer\(\s*id\s*,\s*body\?\.\s*answer\s*\)",
    "this.leads.wizardAnswer(id, body?.key, body?.answer)",
    t
  )
  if n == 0:
    raise SystemExit("❌ Controller patch failed: wizardAnswer call not found.")
ctrl.write_text(t2, encoding="utf-8")
print("✅ Patched controller:", ctrl)

# --- 2) Service: accept key param and use it to update deal snapshot
s = svc.read_text(encoding="utf-8")

# change signature: wizardAnswer(leadId: string, answer?: string) -> wizardAnswer(leadId: string, key?: string, answer?: string)
s2, n = re.subn(
  r"async\s+wizardAnswer\s*\(\s*leadId:\s*string\s*,\s*answer\?\s*:\s*string\s*\)",
  "async wizardAnswer(leadId: string, key?: string, answer?: string)",
  s
)
if n == 0:
  raise SystemExit("❌ Service patch failed: wizardAnswer signature not found.")
s = s2

# ensure field selection uses key if provided
# Find the block: const field = ...;  (your file already has it)
m = re.search(r"const\s+field\s*=\s*[\s\S]*?;\s*", s)
if not m:
  raise SystemExit("❌ Service patch failed: const field = ...; block not found.")

field_block = m.group(0)

# Build a new field block that prioritizes body key
new_field_block = """const field =
      (key && ['city','district','type','rooms'].includes(String(key)) ? String(key) : null) ??
      (!deal.city ? 'city' :
      !deal.district ? 'district' :
      !deal.type ? 'type' :
      !deal.rooms ? 'rooms' :
      null);
"""

s = s[:m.start()] + new_field_block + s[m.end():]

# --- 3) Remove the old injected "propagate" block (optional but strongly recommended)
# It starts with "// --- propagate wizard answer -> deal fields ---" and ends with "// --- end propagate ---"
s = re.sub(r"\s*// --- propagate wizard answer -> deal fields ---[\s\S]*?// --- end propagate ---\s*", "\n", s)

# --- 4) Make the actual deal update use this.prisma.deal.update (single source of truth)
# Replace the weird this.dealsService['prisma'].deal.update with this.prisma.deal.update
s = s.replace("this.dealsService['prisma'].deal.update", "this.prisma.deal.update")

svc.write_text(s, encoding="utf-8")
print("✅ Patched service:", svc)

print("✅ DONE")
PY

echo
echo "✅ Patch tamam."
echo "Şimdi API'yi restart et (3001 çakışmasın diye eskiyi kapat):"
echo "  lsof -nP -iTCP:3001 -sTCP:LISTEN"
echo "  kill -9 <PID>"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Sonra test:"
echo "  cd $ROOT && bash scripts/wizard-and-match-doctor.sh"
