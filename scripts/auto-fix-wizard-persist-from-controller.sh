#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
CTRL="$ROOT/apps/api/src/leads/leads.controller.ts"
SVC="$ROOT/apps/api/src/leads/leads.service.ts"

if [[ ! -f "$CTRL" ]]; then
  echo "❌ Controller not found: $CTRL"
  exit 1
fi
if [[ ! -f "$SVC" ]]; then
  echo "❌ Service not found: $SVC"
  exit 1
fi

python3 - "$CTRL" "$SVC" <<'PY'
import re, sys
from pathlib import Path

ctrl_path = Path(sys.argv[1])
svc_path  = Path(sys.argv[2])

ctrl = ctrl_path.read_text(encoding="utf-8")
svc  = svc_path.read_text(encoding="utf-8")

MARK = "WIZARD_PERSIST_FROM_CONTROLLER_V2"
if MARK in svc:
    print("ℹ️ Patch already applied (marker exists).")
    raise SystemExit(0)

# 1) Find @Post('...wizard/answer...')
route_pat = re.compile(r"@Post\(\s*['\"][^'\"]*wizard/answer['\"]\s*\)")
m = route_pat.search(ctrl)
if not m:
    print("❌ Could not find @Post(...wizard/answer...) in controller.")
    raise SystemExit(2)

# 2) From decorator forward, find the next method signature line that opens a block.
# We accept patterns like:
# async wizardAnswer(@Param('id') id: string, @Body() body: Dto) {
# wizardAnswer(...) {
# public async wizardAnswer(...) {
scan = ctrl[m.end():]

sig_pat = re.compile(
    r"\n\s*(?:public\s+|private\s+|protected\s+)?(?:async\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)\s*\{",
    re.M
)

sig = sig_pat.search(scan)
if not sig:
    print("❌ Could not find handler method signature after wizard/answer decorator (even with wide scan).")
    raise SystemExit(3)

handler_name = sig.group(1)
handler_open_brace_pos = m.end() + sig.end() - 1  # points at '{' in the original ctrl string

# 3) Extract full handler block by brace matching starting at that '{'
depth = 0
i = handler_open_brace_pos
while i < len(ctrl):
    ch = ctrl[i]
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        if depth == 0:
            i += 1
            break
    i += 1

handler_block = ctrl[handler_open_brace_pos:i]

# 4) Find service call inside handler
call = re.search(r"this\.leadsService\.([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)", handler_block, re.S)
if not call:
    print("❌ Could not find this.leadsService.<method>(...) inside handler block.")
    print("Handler:", handler_name)
    raise SystemExit(4)

svc_method = call.group(1)
args_raw = call.group(2)

# Split args safely (basic)
args = [a.strip() for a in re.split(r",(?![^{]*\})", args_raw) if a.strip()]
lead_expr = args[0] if args else "id"

key_expr = None
ans_expr = None
for a in args:
    if key_expr is None and "key" in a:
        key_expr = a
    if ans_expr is None and "answer" in a:
        ans_expr = a
key_expr = key_expr or "key"
ans_expr = ans_expr or "answer"

# 5) Locate the target service method body
mm = re.search(rf"\basync\s+{re.escape(svc_method)}\s*\(([^)]*)\)\s*\{{", svc)
if not mm:
    print(f"❌ Could not find 'async {svc_method}(' in leads.service.ts")
    raise SystemExit(5)

brace = svc.find("{", mm.end()-1)
if brace == -1:
    print("❌ Could not find opening '{' of service method body.")
    raise SystemExit(6)

# Determine indentation
line_start = svc.rfind("\n", 0, mm.start()) + 1
base_indent = re.match(r"[ \t]*", svc[line_start:mm.start()]).group(0)
inner = base_indent + "  "

# Prisma handle detect
prisma_handle = "this.prisma"
if "this.prismaService." in svc and "this.prisma." not in svc:
    prisma_handle = "this.prismaService"
elif "this.db." in svc and "this.prisma." not in svc and "this.prismaService." not in svc:
    prisma_handle = "this.db"

insert = f"""
{inner}// {MARK}: persist wizard answers into Deal (auto-located from controller)
{inner}const __wizKey = {key_expr};
{inner}const __wizAnswer = {ans_expr};
{inner}if (__wizKey && __wizAnswer) {{
{inner}  const data: any = {{}};
{inner}  switch (__wizKey) {{
{inner}    case 'city':
{inner}      data.city = __wizAnswer;
{inner}      break;
{inner}    case 'district':
{inner}      data.district = __wizAnswer;
{inner}      break;
{inner}    case 'type':
{inner}      data.type = __wizAnswer;
{inner}      break;
{inner}    case 'rooms':
{inner}      data.rooms = __wizAnswer; // keep raw like "2+1"
{inner}      break;
{inner}    default:
{inner}      break;
{inner}  }}
{inner}  if (Object.keys(data).length) {{
{inner}    await {prisma_handle}.deal.updateMany({{
{inner}      where: {{ leadId: {lead_expr} }},
{inner}      data,
{inner}    }});
{inner}  }}
{inner}}}
"""

new_svc = svc[:brace+1] + insert + svc[brace+1:]

bak = svc_path.with_suffix(svc_path.suffix + ".autofix2.bak")
bak.write_text(svc, encoding="utf-8")
svc_path.write_text(new_svc, encoding="utf-8")

print("✅ Auto-fix v2 applied via controller route analysis.")
print(f"- Controller handler: {handler_name}")
print(f"- Service method:     {svc_method}")
print(f"- leadId expr:        {lead_expr}")
print(f"- key expr:           {key_expr}")
print(f"- answer expr:        {ans_expr}")
print(f"- Prisma handle:      {prisma_handle}")
print(f"- Updated:            {svc_path}")
print(f"- Backup:             {bak}")
PY
