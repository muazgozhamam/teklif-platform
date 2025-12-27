#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
CTRL="$ROOT/apps/api/src/leads/leads.controller.ts"
SVC="$ROOT/apps/api/src/leads/leads.service.ts"

python3 - "$CTRL" "$SVC" <<'PY'
import re, sys
from pathlib import Path

ctrl_path = Path(sys.argv[1])
svc_path  = Path(sys.argv[2])

ctrl = ctrl_path.read_text(encoding="utf-8")
svc  = svc_path.read_text(encoding="utf-8")

MARK = "WIZARD_PERSIST_FROM_CONTROLLER_V3"
if MARK in svc:
    print("ℹ️ Patch already applied (marker exists).")
    raise SystemExit(0)

# locate decorator
m = re.search(r"@Post\(\s*['\"][^'\"]*wizard/answer['\"]\s*\)", ctrl)
if not m:
    print("❌ Could not find @Post(...wizard/answer...) in controller.")
    raise SystemExit(2)

# from decorator end, find the next method name by scanning for "<name>(" pattern
tail = ctrl[m.end():]

name_m = re.search(r"\n\s*(?:public\s+|private\s+|protected\s+)?(?:async\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(", tail)
if not name_m:
    print("❌ Could not find any method name after decorator.")
    raise SystemExit(3)

handler_name = name_m.group(1)

# find the first "{" after that method name occurrence (handles multiline signatures / return types)
after_name_pos = m.end() + name_m.end()
brace_pos = ctrl.find("{", after_name_pos)
if brace_pos == -1:
    print("❌ Could not find opening '{' after handler name.")
    raise SystemExit(4)

# extract handler block with brace matching
depth = 0
i = brace_pos
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
handler_block = ctrl[brace_pos:i]

# find service call in handler block
call = re.search(r"this\.(\w+)\.([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)", handler_block, re.S)
if not call:
    print("❌ Could not find a call like this.<service>.<method>(...) inside handler.")
    print("Handler:", handler_name)
    # print a short snippet to guide next fix
    snippet = handler_block[:800]
    print("\n--- handler snippet start ---\n" + snippet + "\n--- handler snippet end ---\n")
    raise SystemExit(5)

service_prop = call.group(1)         # e.g., leadsService or leads
svc_method  = call.group(2)          # method name
args_raw    = call.group(3)

# split args roughly
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

# find target method in service file (we assume it's in leads.service.ts for now)
mm = re.search(rf"\basync\s+{re.escape(svc_method)}\s*\(", svc)
if not mm:
    print(f"❌ Could not find async {svc_method}(...) in leads.service.ts")
    print(f"Note: controller calls this.{service_prop}.{svc_method}(...). Service prop may not be leadsService.")
    raise SystemExit(6)

brace = svc.find("{", mm.end())
if brace == -1:
    print("❌ Could not find opening '{' of service method body.")
    raise SystemExit(7)

# indentation
line_start = svc.rfind("\n", 0, mm.start()) + 1
base_indent = re.match(r"[ \t]*", svc[line_start:mm.start()]).group(0)
inner = base_indent + "  "

# prisma handle
prisma_handle = "this.prisma"
if "this.prismaService." in svc and "this.prisma." not in svc:
    prisma_handle = "this.prismaService"
elif "this.db." in svc and "this.prisma." not in svc and "this.prismaService." not in svc:
    prisma_handle = "this.db"

insert = f"""
{inner}// {MARK}: persist wizard answers into Deal (auto-located from controller handler)
{inner}const __wizKey = {key_expr};
{inner}const __wizAnswer = {ans_expr};
{inner}if (__wizKey && __wizAnswer) {{
{inner}  const data: any = {{}};
{inner}  switch (__wizKey) {{
{inner}    case 'city': data.city = __wizAnswer; break;
{inner}    case 'district': data.district = __wizAnswer; break;
{inner}    case 'type': data.type = __wizAnswer; break;
{inner}    case 'rooms': data.rooms = __wizAnswer; break; // keep "2+1"
{inner}    default: break;
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
bak = svc_path.with_suffix(svc_path.suffix + ".autofix3.bak")
bak.write_text(svc, encoding="utf-8")
svc_path.write_text(new_svc, encoding="utf-8")

print("✅ Auto-fix v3 applied.")
print(f"- Controller handler: {handler_name}")
print(f"- Controller call:    this.{service_prop}.{svc_method}(...)")
print(f"- leadId expr:        {lead_expr}")
print(f"- key expr:           {key_expr}")
print(f"- answer expr:        {ans_expr}")
print(f"- Prisma handle:      {prisma_handle}")
print(f"- Updated:            {svc_path}")
print(f"- Backup:             {bak}")
PY
