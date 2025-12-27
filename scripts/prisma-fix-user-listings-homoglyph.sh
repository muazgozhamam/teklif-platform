#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "SCHEMA=$SCHEMA"

[ -f "$SCHEMA" ] || { echo "❌ schema.prisma not found: $SCHEMA"; exit 1; }

cp "$SCHEMA" "$SCHEMA.bak.$(date +%Y%m%d-%H%M%S)"
echo "✅ Backup alındı"

SCHEMA="$SCHEMA" python3 - <<'PY'
from pathlib import Path
import os, re

p = Path(os.environ["SCHEMA"]).resolve()
txt = p.read_text(encoding="utf-8", errors="replace").replace("\r\n","\n").replace("\r","\n")

# ---- 1) Find model blocks
def find_block(name: str):
    m = re.search(rf'(?ms)^\s*model\s+{re.escape(name)}\s*\{{.*?^\s*\}}', txt)
    return m

mu = find_block("User")
ml = find_block("Listing")
if not mu:
    raise SystemExit("❌ model User bulunamadı")
if not ml:
    raise SystemExit("❌ model Listing bulunamadı (Listing modelin yoksa önce onu eklemeliyiz)")

user_block = mu.group(0)
listing_block = ml.group(0)

# ---- 2) In User: remove ANY line that contains Listing[]
user_lines = user_block.splitlines(True)
new_user_lines = []
removed_user = 0
for line in user_lines:
    if re.search(r'\bListing\[\]\b', line):
        removed_user += 1
        continue
    new_user_lines.append(line)

# insert canonical backrelation with a SAFE name (not "listings")
insert_line = '  userListings Listing[] @relation("UserListings")\n'
for i in range(len(new_user_lines)-1, -1, -1):
    if re.match(r'^\s*\}\s*$', new_user_lines[i]):
        new_user_lines.insert(i, insert_line)
        break
else:
    raise SystemExit("❌ User block kapanış '}' bulunamadı")

new_user_block = "".join(new_user_lines)

# ---- 3) In Listing: ensure consultant relation uses same relation name
# We expect something like:
# consultantId String
# consultant   User    @relation(fields: [consultantId], references: [id], onDelete: Restrict)
#
# We will FORCE the consultant line to include @relation("UserListings", ...)
lb = listing_block

# normalize: remove any existing @relation("UserListings"... ) duplicates in consultant line by rewriting the whole line
# Find a consultant field line referencing User with fields: [consultantId]
pat_consultant = re.compile(r'(?m)^\s*consultant\s+User\s+@relation\([^\)]*\)\s*$')
m_cons = pat_consultant.search(lb)
if not m_cons:
    raise SystemExit("❌ Listing model içinde consultant User @relation(...) satırı bulunamadı")

# Rewrite consultant relation line
new_cons_line = '  consultant   User    @relation("UserListings", fields: [consultantId], references: [id], onDelete: Restrict)\n'
lb2 = lb[:m_cons.start()] + new_cons_line + lb[m_cons.end():]

# Ensure consultantId exists
if not re.search(r'(?m)^\s*consultantId\s+String\b', lb2):
    raise SystemExit("❌ Listing model içinde consultantId String yok. Önce onu eklemeliyiz.")

new_listing_block = lb2

# ---- 4) Write back
txt2 = txt[:mu.start()] + new_user_block + txt[mu.end():]
# Re-find listing block positions after user edit
m2 = re.search(r'(?ms)^\s*model\s+Listing\s*\{.*?^\s*\}', txt2)
if not m2:
    raise SystemExit("❌ Listing block ikinci aramada bulunamadı")
txt2 = txt2[:m2.start()] + new_listing_block + txt2[m2.end():]

# final normalize
txt2 = "\n".join(line.rstrip() for line in txt2.split("\n")) + "\n"
p.write_text(txt2, encoding="utf-8")

print(f"✅ Patched: removed {removed_user} line(s) containing Listing[] from User; added userListings relation.")
PY

echo
echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma

echo "✅ prisma format OK"
