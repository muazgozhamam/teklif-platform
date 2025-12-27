#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "==> Root: $ROOT_DIR"
echo "==> API:  $API_DIR"
echo "==> Schema: $SCHEMA"
echo

if [[ ! -f "$SCHEMA" ]]; then
  echo "ERROR: schema not found at: $SCHEMA"
  exit 1
fi

echo "==> 0) Backup"
TS="$(date +%Y%m%d-%H%M%S)"
cp "$SCHEMA" "$SCHEMA.bak.$TS"
echo "Backed up schema -> $SCHEMA.bak.$TS"
echo

echo "==> 1) Detect Role enum values + decide consultant role key"
CONSULTANT_ROLE="$(
python3 - <<'PY'
import re, pathlib, sys

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

m = re.search(r'enum\s+Role\s*\{([\s\S]*?)\n\}', txt)
if not m:
    print("", end="")
    sys.exit(0)

body = m.group(1)
vals = []
for line in body.splitlines():
    line = line.strip()
    if not line or line.startswith("//"):
        continue
    tok = re.split(r"\s+", line)[0]
    if tok.startswith("@"):
        continue
    vals.append(tok)

cand = [v for v in vals if "CONSULTANT" in v.upper()]
if cand:
    for v in cand:
        if v.upper() == "CONSULTANT":
            print(v, end="")
            sys.exit(0)
    print(cand[0], end="")
    sys.exit(0)

print("__MISSING__", end="")
PY
"$SCHEMA"
)"

if [[ -z "$CONSULTANT_ROLE" ]]; then
  echo "ERROR: enum Role not found in schema.prisma"
  exit 1
fi

if [[ "$CONSULTANT_ROLE" == "__MISSING__" ]]; then
  echo "Role enum found but no CONSULTANT-like value. Will add: CONSULTANT"
  CONSULTANT_ROLE="CONSULTANT"

  echo "==> 2) Patch schema: add CONSULTANT into enum Role (if not already)"
  python3 - <<'PY'
import re, pathlib, sys

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

m = re.search(r'(enum\s+Role\s*\{)([\s\S]*?)(\n\})', txt)
if not m:
    print("ERROR: enum Role block not found")
    sys.exit(1)

head, body, tail = m.group(1), m.group(2), m.group(3)

if re.search(r'(?im)^\s*CONSULTANT\s*$', body):
    print("Schema already contains CONSULTANT; no changes.")
    sys.exit(0)

new_body = body.rstrip() + "\n  CONSULTANT\n"
new_txt = txt[:m.start()] + head + new_body + tail + txt[m.end():]
p.write_text(new_txt, encoding="utf-8")
print("PATCHED schema: added CONSULTANT to enum Role")
PY
"$SCHEMA"
else
  echo "Detected consultant role enum value in schema: $CONSULTANT_ROLE"
fi

echo
echo "==> 3) Patch code usage under apps/api/src"
TARGET_DIR="$API_DIR/src"

# Replace role: "CONSULTANT" / 'CONSULTANT'
find "$TARGET_DIR" -type f \( -name "*.ts" -o -name "*.tsx" \) -print0 \
  | xargs -0 perl -pi -e "s/role:\s*\"CONSULTANT\"/role: \"$CONSULTANT_ROLE\"/g; s/role:\s*'CONSULTANT'/role: '$CONSULTANT_ROLE'/g"

# Also replace common patterns like equals checks or strings if used as a filter variable
find "$TARGET_DIR" -type f \( -name "*.ts" -o -name "*.tsx" \) -print0 \
  | xargs -0 perl -pi -e "s/\"CONSULTANT\"/\"$CONSULTANT_ROLE\"/g if /role/; s/'CONSULTANT'/'$CONSULTANT_ROLE'/g if /role/"

echo "Patched occurrences under: $TARGET_DIR"
echo

echo "==> 4) Prisma format + generate + db push + build"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s prisma db push --schema prisma/schema.prisma
pnpm -s build

echo
echo "✅ DONE"
echo "Now restart API, then retry:"
echo "  curl -i -X POST \"http://localhost:3001/deals/cmjmdz7rj0001grmfeyx69qie/match\""
