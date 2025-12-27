#!/usr/bin/env bash
set -euo pipefail

APP="apps/api/src/app.module.ts"
if [ ! -f "$APP" ]; then
  echo "ERROR: $APP yok"
  exit 1
fi

echo "==> Force-register CommissionsModule + DealFinalizeModule in $APP"

python3 - <<'PY'
import re, pathlib
p = pathlib.Path("apps/api/src/app.module.ts")
s = p.read_text(encoding="utf-8")

# Ensure imports exist
def ensure_import(line):
  nonlocal_s[0]
nonlocal_s = [s]

def add_import(import_line):
  s = nonlocal_s[0]
  if import_line in s:
    return
  lines = s.splitlines()
  last_import = 0
  for i,l in enumerate(lines):
    if l.startswith("import "):
      last_import = i
  lines.insert(last_import+1, import_line)
  nonlocal_s[0] = "\n".join(lines) + ("\n" if not s.endswith("\n") else "")

add_import("import { CommissionsModule } from './commissions/commissions.module';")
add_import("import { DealFinalizeModule } from './deal-finalize/deal-finalize.module';")

s = nonlocal_s[0]

# Find @Module({ ... })
m = re.search(r"@Module\(\s*\{([\s\S]*?)\}\s*\)\s*export\s+class\s+AppModule", s)
if not m:
  raise SystemExit("ERROR: @Module({...}) export class AppModule bulunamadı")

block = m.group(1)

# Locate imports: [...]
m2 = re.search(r"imports\s*:\s*\[([\s\S]*?)\]", block)
if not m2:
  # create imports array at top of module block
  new_block = "  imports: [CommissionsModule, DealFinalizeModule],\n" + block.lstrip()
  s = s[:m.start(1)] + new_block + s[m.end(1):]
else:
  inside = m2.group(1)
  # Remove any accidental string typing/casts around imports (best effort)
  inside2 = inside
  # Ensure modules are present
  if re.search(r"\bCommissionsModule\b", inside2) is None:
    inside2 = "    CommissionsModule,\n" + inside2
  if re.search(r"\bDealFinalizeModule\b", inside2) is None:
    inside2 = "    DealFinalizeModule,\n" + inside2
  # Replace imports content
  new_block = block[:m2.start(1)] + inside2 + block[m2.end(1):]
  s = s[:m.start(1)] + new_block + s[m.end(1):]

p.write_text(s, encoding="utf-8")
print("OK: app.module.ts updated")
PY

echo "==> Show patched section"
nl -ba "$APP" | sed -n '1,120p'
