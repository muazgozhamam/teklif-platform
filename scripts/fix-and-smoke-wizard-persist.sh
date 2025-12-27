#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SVC="$API_DIR/src/leads/leads.service.ts"
LOG="$ROOT/.tmp-wizpersist.log"
PORT="${PORT:-3001}"
BASE_URL="${BASE_URL:-http://localhost:${PORT}}"

echo "==> 0) Patch leads.service.ts (wizardAnswer persist + logs)"
python3 - <<'PY' "$SVC"
import re, sys
from pathlib import Path

p=Path(sys.argv[1])
txt=p.read_text(encoding="utf-8")

m=re.search(r"\basync\s+wizardAnswer\s*\(([^)]*)\)\s*\{", txt)
if not m:
    print("❌ wizardAnswer not found")
    raise SystemExit(2)

sig=m.group(1)

# robust param name capture: name before ":" and allow optional "?"
# examples: "leadId: string", "key?: string", "answer?: string"
names=[]
for part in sig.split(","):
    part=part.strip()
    mm=re.search(r"^([A-Za-z_]\w*)\s*\??\s*:", part)
    if mm:
        names.append(mm.group(1))

if len(names) < 3:
    print("❌ wizardAnswer params parse failed:", sig)
    raise SystemExit(3)

leadId, key, answer = names[0], names[1], names[2]

# remove any old injected wizard persist blocks we might have added earlier
txt2 = re.sub(r"\n[ \t]*//\s*WIZARD_DEAL_[A-Z0-9_]+[\s\S]*?(?=\n[ \t]*\S)", "\n", txt, flags=re.S)

brace = txt2.find("{", m.end()-1)
if brace == -1:
    print("❌ wizardAnswer body brace not found")
    raise SystemExit(4)

line_start = txt2.rfind("\n", 0, m.start()) + 1
base_indent = re.match(r"[ \t]*", txt2[line_start:m.start()]).group(0)
inner = base_indent + "  "

prisma_handle = "this.prisma"
if "this.prismaService." in txt2 and "this.prisma." not in txt2:
    prisma_handle = "this.prismaService"
elif "this.db." in txt2 and "this.prisma." not in txt2 and "this.prismaService." not in txt2:
    prisma_handle = "this.db"

MARK="WIZARD_DEAL_UPSERT_PERSIST_V2"

insert = f"""
{inner}// {MARK}
{inner}// eslint-disable-next-line no-console
{inner}console.log('WIZPERS_IN', {{ {leadId}, {key}, {answer} }});

{inner}if ({key} && {answer}) {{
{inner}  const data: any = {{}};
{inner}  const k = String({key}).trim();
{inner}  const a = String({answer}).trim();
{inner}  switch (k) {{
{inner}    case 'city': data.city = a; break;
{inner}    case 'district': data.district = a; break;
{inner}    case 'type': data.type = a; break;
{inner}    case 'rooms': data.rooms = a; break;
{inner}    default: break;
{inner}  }}
{inner}  if (Object.keys(data).length) {{
{inner}    const after = await {prisma_handle}.deal.upsert({{
{inner}      where: {{ leadId: {leadId} }},
{inner}      update: data,
{inner}      create: {{
{inner}        leadId: {leadId},
{inner}        ...data,
{inner}      }},
{inner}      select: {{ id:true, status:true, city:true, district:true, type:true, rooms:true, leadId:true }},
{inner}    }});
{inner}    // eslint-disable-next-line no-console
{inner}    console.log('WIZPERS_UPSERT_OK', after);
{inner}  }} else {{
{inner}    // eslint-disable-next-line no-console
{inner}    console.log('WIZPERS_SKIP_KEY', k);
{inner}  }}
{inner}}} else {{
{inner}  // eslint-disable-next-line no-console
{inner}  console.log('WIZPERS_SKIP_EMPTY');
{inner}}}
"""

bak = p.with_suffix(p.suffix + ".wizpers.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(txt2[:brace+1] + insert + txt2[brace+1:], encoding="utf-8")

print("✅ Patched wizardAnswer persist+logs.")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- Params: leadId={leadId}, key={key}, answer={answer}")
print(f"- Prisma handle: {prisma_handle}")
PY

echo
echo "==> 1) Build API (dist)"
cd "$API_DIR"
pnpm -s build

echo
echo "==> 2) Free port $PORT"
cd "$ROOT"
PIDS="$(lsof -nP -t -iTCP:${PORT} -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

echo
echo "==> 3) Start API from dist (background) -> $LOG"
rm -f "$LOG"
PORT="$PORT" node "$API_DIR/dist/src/main.js" >"$LOG" 2>&1 &
API_PID=$!
echo "API_PID=$API_PID"

echo
echo "==> 4) Wait health"
for i in {1..40}; do
  if curl -sS "$BASE_URL/health" >/dev/null 2>&1; then
    echo "OK: health"
    break
  fi
  sleep 0.2
done

echo
echo "==> 5) Run doctor"
BASE_URL="$BASE_URL" bash scripts/wizard-and-match-doctor.sh || true

echo
echo "==> 6) Stop API"
kill -9 "$API_PID" || true

echo
echo "==> 7) Show WIZPERS logs"
rg -n "WIZPERS_" "$LOG" || echo "WIZPERS yok (wizardAnswer'a hiç girilmedi ya da log yazılmadı)"
echo
echo "==> DONE (log: $LOG)"
