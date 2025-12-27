#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
API_DIR="$ROOT_DIR/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"
SRC_DIR="$API_DIR/src"

echo "==> ROOT:   $ROOT_DIR"
echo "==> API:    $API_DIR"
echo "==> SCHEMA: $SCHEMA"
echo

[[ -f "$SCHEMA" ]] || { echo "ERROR: schema not found: $SCHEMA"; exit 1; }

echo "==> 0) Ensure schema is writable"
if [[ ! -w "$SCHEMA" ]]; then
  echo "Schema is not writable. Running: chmod u+w \"$SCHEMA\""
  chmod u+w "$SCHEMA"
fi
echo "OK: schema writable"
echo

echo "==> 1) Backup schema"
TS="$(date +%Y%m%d-%H%M%S)"
cp "$SCHEMA" "$SCHEMA.bak.$TS"
echo "Backup: $SCHEMA.bak.$TS"
echo

echo "==> 2) Detect consultant role enum value (or add CONSULTANT)"
CONSULTANT_ROLE="$(python3 - "$SCHEMA" <<'PY'
import re, sys, pathlib

schema_path = sys.argv[1]
p = pathlib.Path(schema_path)
txt = p.read_text(encoding="utf-8")

m = re.search(r'enum\s+Role\s*\{([\s\S]*?)\n\}', txt)
if not m:
    print("")
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
    # prefer exact CONSULTANT
    for v in cand:
        if v.upper() == "CONSULTANT":
            print(v)
            sys.exit(0)
    print(cand[0])
    sys.exit(0)

print("__MISSING__")
PY
)"

if [[ -z "$CONSULTANT_ROLE" ]]; then
  echo "ERROR: enum Role not found in schema.prisma"
  exit 1
fi

if [[ "$CONSULTANT_ROLE" == "__MISSING__" ]]; then
  echo "No CONSULTANT-like value in enum Role. Adding CONSULTANT..."
  python3 - "$SCHEMA" <<'PY'
import re, sys, pathlib

schema_path = sys.argv[1]
p = pathlib.Path(schema_path)
txt = p.read_text(encoding="utf-8")

m = re.search(r'(enum\s+Role\s*\{)([\s\S]*?)(\n\})', txt)
if not m:
    raise SystemExit("ERROR: enum Role block not found")

head, body, tail = m.group(1), m.group(2), m.group(3)

# already exists?
if re.search(r'(?im)^\s*CONSULTANT\s*$', body):
    print("Schema already has CONSULTANT. No change.")
    raise SystemExit(0)

new_body = body.rstrip() + "\n  CONSULTANT\n"
out = txt[:m.start()] + head + new_body + tail + txt[m.end():]
p.write_text(out, encoding="utf-8")
print("PATCHED schema: added CONSULTANT to enum Role")
PY
  CONSULTANT_ROLE="CONSULTANT"
else
  echo "Detected consultant enum value: $CONSULTANT_ROLE"
fi

echo
echo "==> 3) Patch code under apps/api/src (role filters)"
[[ -d "$SRC_DIR" ]] || { echo "ERROR: src dir not found: $SRC_DIR"; exit 1; }

# Replace role: "CONSULTANT" and role: 'CONSULTANT'
find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" \) -print0 \
  | xargs -0 perl -pi -e "s/role:\s*\"CONSULTANT\"/role: \"$CONSULTANT_ROLE\"/g; s/role:\s*'CONSULTANT'/role: '$CONSULTANT_ROLE'/g"

# Safety: replace any remaining "CONSULTANT" literals only on lines mentioning role
find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" \) -print0 \
  | xargs -0 perl -pi -e "if (/role/){s/\"CONSULTANT\"/\"$CONSULTANT_ROLE\"/g; s/'CONSULTANT'/'$CONSULTANT_ROLE'/g}"

echo "Patched code to use Role.$CONSULTANT_ROLE"
echo

echo "==> 4) Prisma format + generate + db push + build"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s prisma db push --schema prisma/schema.prisma
pnpm -s build

echo
echo "==> 5) Quick verification (should be empty):"
cd "$ROOT_DIR"
grep -R --line-number 'role: "CONSULTANT"' apps/api/src || true
grep -R --line-number "role: 'CONSULTANT'" apps/api/src || true

echo
echo "✅ DONE"
echo "Next:"
echo "  1) Restart API (pnpm start:dev vs.)"
echo "  2) Retry:"
echo "     curl -i -X POST \"http://localhost:3001/deals/cmjmdz7rj0001grmfeyx69qie/match\""
