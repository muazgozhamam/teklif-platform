#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SRC="$API_DIR/src/leads/leads.service.ts"
DIST_DIR="$API_DIR/dist"
LOG="$ROOT/.tmp-ansdeal.smoke.log"
PORT="${PORT:-3001}"
BASE_URL="http://localhost:${PORT}"

echo "==> 0) Preconditions"
[[ -f "$SRC" ]] || { echo "❌ Missing $SRC"; exit 1; }
[[ -f "$API_DIR/.env" ]] || { echo "❌ Missing $API_DIR/.env"; exit 2; }

DB_URL="$(awk -F= '/^DATABASE_URL=/{sub(/^DATABASE_URL=/,""); print; exit}' "$API_DIR/.env" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
[[ -n "$DB_URL" ]] || { echo "❌ DATABASE_URL not found in $API_DIR/.env"; exit 3; }

echo "==> 1) Patch LeadsService.upsertAnswer() to also upsert Deal"
python3 - <<'PY'
import re
from pathlib import Path

p = Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8")

MARK = "ANSDEAL_UPSERT_V1"
if MARK in txt:
    print("ℹ️ Patch already applied (marker exists).")
    raise SystemExit(0)

m = re.search(r"\basync\s+upsertAnswer\s*\(", txt)
if not m:
    print("❌ upsertAnswer method not found.")
    raise SystemExit(2)

brace_open = txt.find("{", m.end())
if brace_open < 0:
    print("❌ Could not find upsertAnswer body.")
    raise SystemExit(3)

i = brace_open + 1
depth = 1
while i < len(txt) and depth > 0:
    if txt[i] == "{": depth += 1
    elif txt[i] == "}": depth -= 1
    i += 1
brace_close = i

method = txt[m.start():brace_close]

sig = re.search(r"\basync\s+upsertAnswer\s*\(([^)]*)\)", method)
if not sig:
    print("❌ Could not parse upsertAnswer signature.")
    raise SystemExit(4)

params = [x.strip() for x in sig.group(1).split(",")]
if len(params) < 3:
    print("❌ upsertAnswer signature expects 3 params.")
    print("Got:", sig.group(1))
    raise SystemExit(5)

lead_expr = params[0].split(":")[0].strip()
key_expr  = params[1].split(":")[0].strip()
ans_expr  = params[2].split(":")[0].strip()

prisma_handle = "this.prisma"
if "this.prismaService" in txt and "this.prisma" not in txt:
    prisma_handle = "this.prismaService"
elif "this.db" in txt and "this.prisma" not in txt and "this.prismaService" not in txt:
    prisma_handle = "this.db"

# indentation (first non-empty line inside method)
lines = method.splitlines(True)
indent = ""
for ln in lines[1:]:
    if ln.strip():
        indent = re.match(r"[ \t]*", ln).group(0)
        break

# insert near end, before last closing brace; prefer before final return if present
ins = method.rfind("\n" + indent + "return ")
if ins == -1:
    ins = len(method) - 1

block = f"""
{indent}// {MARK}
{indent}try {{
{indent}  console.log('ANSDEAL_IN', {{ leadId: {lead_expr}, key: {key_expr}, answer: {ans_expr} }});
{indent}}} catch (e) {{}}
{indent}if ({key_expr} && {ans_expr}) {{
{indent}  const data: any = {{}};
{indent}  const k = String({key_expr}).trim();
{indent}  const a = String({ans_expr}).trim();
{indent}  switch (k) {{
{indent}    case 'city': data.city = a; break;
{indent}    case 'district': data.district = a; break;
{indent}    case 'type': data.type = a; break;
{indent}    case 'rooms': data.rooms = a; break;
{indent}    default: break;
{indent}  }}
{indent}  if (Object.keys(data).length) {{
{indent}    const after = await {prisma_handle}.deal.upsert({{
{indent}      where: {{ leadId: {lead_expr} }},
{indent}      update: data,
{indent}      create: {{ leadId: {lead_expr}, ...data }},
{indent}      select: {{ id:true,status:true,city:true,district:true,type:true,rooms:true,leadId:true }},
{indent}    }});
{indent}    console.log('ANSDEAL_UPSERT_OK', after);
{indent}  }} else {{
{indent}    console.log('ANSDEAL_SKIP_KEY', k);
{indent}  }}
{indent}}} else {{
{indent}  console.log('ANSDEAL_SKIP_EMPTY');
{indent}}}
"""

new_method = method[:ins] + block + method[ins:]
new_txt = txt[:m.start()] + new_method + txt[brace_close:]

bak = p.with_suffix(p.suffix + ".ansdeal.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ Patched upsertAnswer() to persist Deal fields too.")
print(f"- Updated: {p}")
print(f"- Backup : {bak}")
print(f"- leadId expr: {lead_expr}")
print(f"- key expr   : {key_expr}")
print(f"- answer expr: {ans_expr}")
print(f"- prisma     : {prisma_handle}")
PY

echo
echo "==> 2) Stop anything on port $PORT"
PIDS="$(lsof -nP -t -iTCP:${PORT} -sTCP:LISTEN || true)"
if [[ -n "${PIDS}" ]]; then
  echo "Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

echo
echo "==> 3) Clean dist + build"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
pnpm -s -C "$API_DIR" build

echo
echo "==> 4) Start API from dist with DATABASE_URL -> $LOG"
rm -f "$LOG"
DATABASE_URL="$DB_URL" PORT="$PORT" node "$API_DIR/dist/src/main.js" >"$LOG" 2>&1 &
API_PID=$!
echo "API_PID=$API_PID"

echo
echo "==> 5) Wait health"
ok=0
for i in {1..80}; do
  if curl -sS "$BASE_URL/health" >/dev/null 2>&1; then
    ok=1
    echo "OK: health"
    break
  fi
  sleep 0.25
done
if [[ "$ok" != "1" ]]; then
  echo "❌ API didn't become healthy. Last 120 log lines:"
  tail -n 120 "$LOG" || true
  kill -9 "$API_PID" || true
  exit 4
fi

echo
echo "==> 6) Run doctor (capture leadId)"
TMP_OUT="$ROOT/.tmp-doctor.out"
BASE_URL="$BASE_URL" bash scripts/wizard-and-match-doctor.sh | tee "$TMP_OUT" >/dev/null || true

LEAD_ID="$(rg -n "leadId=" "$TMP_OUT" | head -n 1 | sed -E 's/.*leadId=([a-z0-9_]+).*/\1/')"
[[ -n "$LEAD_ID" ]] || { echo "❌ Could not parse leadId"; tail -n 80 "$TMP_OUT" || true; }

echo "Parsed leadId=$LEAD_ID"

echo
echo "==> 7) Deal by lead (API)"
curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID" | node -e "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{try{console.log(JSON.stringify(JSON.parse(s),null,2))}catch{console.log(s)}})"

echo
echo "==> 8) Show ANSDEAL logs"
sleep 0.3
rg -n "ANSDEAL_" "$LOG" || echo "ANSDEAL yok"

echo
echo "==> 9) Stop API"
kill "$API_PID" >/dev/null 2>&1 || true
sleep 0.6
if kill -0 "$API_PID" >/dev/null 2>&1; then
  kill -9 "$API_PID" >/dev/null 2>&1 || true
fi

echo
echo "==> DONE"
echo "- Log: $LOG"
