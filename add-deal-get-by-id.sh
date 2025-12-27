#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"
CTRL="$API/src/deals/deals.controller.ts"
SVC="$API/src/deals/deals.service.ts"

[[ -f "$CTRL" ]] || { echo "ERROR: controller not found: $CTRL"; exit 1; }
[[ -f "$SVC" ]] || { echo "ERROR: service not found: $SVC"; exit 1; }

echo "==> 0) Backup"
TS="$(date +%Y%m%d-%H%M%S)"
cp "$CTRL" "$CTRL.bak.$TS"
cp "$SVC" "$SVC.bak.$TS"
echo "Backups created."
echo

echo "==> 1) Patch controller: add GET /deals/:id if missing"
python3 - "$CTRL" <<'PY'
import re, sys, pathlib

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# quick check: already has @Get(':id') or @Get(":id")
if re.search(r'@Get\(\s*[\'"]:\s*id[\'"]\s*\)', txt) or re.search(r'@Get\(\s*[\'"]:\s*id[\'"]\s*\)', txt):
    print("Controller already has @Get(':id') (or similar). Skipping.")
    sys.exit(0)

# Ensure Param import exists
if "Param" not in txt:
    # naive: add Param to existing nest imports line
    txt2 = re.sub(r'from\s+[\'"]@nestjs/common[\'"]\s*;\s*',
                  lambda m: m.group(0), txt)
# Better: patch the import line that contains Controller/Get/Post etc.
m = re.search(r'import\s*\{\s*([^}]+)\}\s*from\s*[\'"]@nestjs/common[\'"]\s*;', txt)
if not m:
    raise SystemExit("ERROR: Could not find @nestjs/common import in controller")

imports = m.group(1)
if "Param" not in imports:
    new_imports = imports.rstrip() + ", Param"
    txt = txt[:m.start(1)] + new_imports + txt[m.end(1):]

# Find class body start
mc = re.search(r'export\s+class\s+\w+\s*\{', txt)
if not mc:
    raise SystemExit("ERROR: Could not find controller class")

insert_pos = mc.end()

method = """
  
  @Get(':id')
  async getById(@Param('id') id: string) {
    return this.dealsService.getById(id);
  }
"""

txt = txt[:insert_pos] + method + txt[insert_pos:]
p.write_text(txt, encoding="utf-8")
print("PATCHED controller: added getById")
PY

echo
echo "==> 2) Patch service: add getById if missing"
python3 - "$SVC" <<'PY'
import re, sys, pathlib

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

if re.search(r'\bgetById\s*\(\s*id\s*:\s*string', txt):
    print("Service already has getById. Skipping.")
    sys.exit(0)

# Find class start
mc = re.search(r'export\s+class\s+\w+\s*\{', txt)
if not mc:
    raise SystemExit("ERROR: Could not find service class")

# Insert near end: before last }
end = txt.rfind("}")
if end == -1:
    raise SystemExit("ERROR: malformed service file")

method = """

  async getById(id: string) {
    // Basic fetch; include relations as needed
    return this.prisma.deal.findUnique({
      where: { id },
      include: {
        lead: true,
        consultant: true,
      },
    });
  }
"""

txt = txt[:end] + method + "\n" + txt[end:]
p.write_text(txt, encoding="utf-8")
print("PATCHED service: added getById")
PY

echo
echo "==> 3) Build"
cd "$API"
pnpm -s build

echo
echo "✅ DONE"
echo "Restart API, then test:"
echo "  curl -i \"http://localhost:3001/deals/cmjmdz7rj0001grmfeyx69qie\""
