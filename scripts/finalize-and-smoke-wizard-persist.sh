#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SRC="$API_DIR/src/leads/leads.service.ts"
DIST_DIR="$API_DIR/dist"
LOG="$ROOT/.tmp-wizpersist.final.log"
PORT="${PORT:-3001}"
BASE_URL="${BASE_URL:-http://localhost:${PORT}}"

echo "==> 0) Preconditions"
[[ -f "$SRC" ]] || { echo "❌ Missing $SRC"; exit 1; }
[[ -f "$API_DIR/.env" ]] || { echo "❌ Missing $API_DIR/.env (DATABASE_URL must be here)"; exit 2; }

DB_URL="$(awk -F= '/^DATABASE_URL=/{sub(/^DATABASE_URL=/,""); print; exit}' "$API_DIR/.env" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
[[ -n "$DB_URL" ]] || { echo "❌ DATABASE_URL not found in $API_DIR/.env"; exit 3; }

echo "==> 1) Cleanup WIZDBG debug remnants (keep WIZPERS)"
python3 - <<'PY'
from pathlib import Path
p = Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8").splitlines(True)

out = []
i = 0
removed = 0

while i < len(txt):
    line = txt[i]

    # Remove any line containing WIZDBG markers or old wizdbg backups
    if "WIZDBG_" in line or ".wizdbg" in line or "wizdbg" in line and "WIZPERS" not in line:
        removed += 1
        i += 1
        continue

    # Remove try/catch wrappers that were only used for WIZDBG logs:
    # try { console.log('WIZDBG_...') } catch(e) {}
    if line.strip() == "try {" and i+1 < len(txt) and "WIZDBG_" in txt[i+1]:
        # skip try line + inner + optional closing + catch block
        removed += 1
        i += 1
        # skip until we pass a line that contains "catch" and the following line (block close), if present
        while i < len(txt) and "catch" not in txt[i]:
            removed += 1
            i += 1
        if i < len(txt) and "catch" in txt[i]:
            removed += 1
            i += 1
            # often next line is "}"; remove if exists
            if i < len(txt) and txt[i].strip() == "}":
                removed += 1
                i += 1
        continue

    out.append(line)
    i += 1

new = "".join(out)
bak = p.with_suffix(p.suffix + ".wizdbg-clean.bak")
bak.write_text("".join(txt), encoding="utf-8")
p.write_text(new, encoding="utf-8")

print(f"✅ Cleaned WIZDBG remnants. removed_lines={removed}")
print(f"- Updated: {p}")
print(f"- Backup : {bak}")
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
if [[ -z "${LEAD_ID}" ]]; then
  echo "❌ Could not parse leadId from doctor output."
  echo "Doctor output tail:"
  tail -n 80 "$TMP_OUT" || true
else
  echo "Parsed leadId=$LEAD_ID"
fi

echo
echo "==> 7) Deal by lead (API)"
if [[ -n "${LEAD_ID}" ]]; then
  echo "GET $BASE_URL/deals/by-lead/$LEAD_ID"
  curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID" | node -e "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{try{console.log(JSON.stringify(JSON.parse(s),null,2))}catch{console.log(s)}})"
fi

echo
echo "==> 8) Show WIZPERS logs (last 200 matches)"
# give Node a moment to flush
sleep 0.3
rg -n "WIZPERS_" "$LOG" || echo "WIZPERS yok"

echo
echo "==> 9) Stop API (graceful)"
kill "$API_PID" >/dev/null 2>&1 || true
# wait a bit, then hard kill if needed
sleep 0.6
if kill -0 "$API_PID" >/dev/null 2>&1; then
  kill -9 "$API_PID" >/dev/null 2>&1 || true
fi

echo
echo "==> DONE"
echo "- Log: $LOG"
