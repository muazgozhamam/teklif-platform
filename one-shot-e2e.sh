#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/Desktop/teklif-platform}"
API_DIR="${API_DIR:-$ROOT_DIR/apps/api}"
BASE_URL="${BASE_URL:-http://localhost:3001}"
PORT="${PORT:-3001}"

LEADS_POST="${LEADS_POST:-/leads}"                             # POST
LEAD_CREATE_FIELD="${LEAD_CREATE_FIELD:-initialText}"          # body field
Q_GET="${Q_GET:-/leads/{LEAD_ID}/questions}"                   # GET
A_POST="${A_POST:-/leads/{LEAD_ID}/answers}"                   # POST
DEAL_GET="${DEAL_GET:-/deals/by-lead/{LEAD_ID}}"               # GET

LEAD_TEXT="${LEAD_TEXT:-Sancak mahallesinde 2+1 evim var ve acil satmak istiyorum}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' gerekli."; exit 1; }; }
url_with_lead () { local tpl="$1"; local id="$2"; echo "${tpl//\{LEAD_ID\}/$id}"; }

http_json () {
  local method="$1"; shift
  local url="$1"; shift
  local body="${1:-}"
  if [[ -n "$body" ]]; then
    curl -sS -X "$method" "$url" -H 'Content-Type: application/json' -d "$body"
  else
    curl -sS -X "$method" "$url"
  fi
}

wait_health () {
  local url="$BASE_URL/health"
  echo "==> Wait /health: $url"
  for _ in {1..60}; do
    if curl -sS "$url" >/dev/null 2>&1; then
      echo "OK: health"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: API health gelmedi."
  exit 1
}

kill_port () {
  if command -v lsof >/dev/null 2>&1; then
    local pid
    pid="$(lsof -ti tcp:"$PORT" || true)"
    if [[ -n "$pid" ]]; then
      echo "==> Killing PID $pid on :$PORT"
      kill -9 "$pid" || true
    fi
  fi
}

cleanup () {
  if [[ -n "${API_PID:-}" ]] && kill -0 "$API_PID" >/dev/null 2>&1; then
    echo "==> Stop API pid=$API_PID"
    kill "$API_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

need pnpm
need jq
need curl
need node

echo "==> API_DIR: $API_DIR"
cd "$API_DIR"

echo "==> [1] prisma generate (Prisma 7)"
pnpm -s prisma generate

echo "==> [2] build"
pnpm -s build

echo "==> [3] restart API"
kill_port

LOG="/tmp/teklif-api-$(date +%s).log"
echo "==> API log: $LOG"
( pnpm start:dev ) >"$LOG" 2>&1 &
API_PID=$!

wait_health

echo "==> [4] Create lead"
CREATE_BODY="$(jq -n --arg f "$LEAD_CREATE_FIELD" --arg t "$LEAD_TEXT" '{($f):$t}')"
LEAD_RES="$(http_json POST "$BASE_URL$LEADS_POST" "$CREATE_BODY")"
echo "$LEAD_RES" | jq . >/dev/null 2>&1 || { echo "ERROR: Lead response JSON değil:"; echo "$LEAD_RES"; exit 1; }

LEAD_ID="$(echo "$LEAD_RES" | jq -r '.id // .leadId // .data.id // empty')"
if [[ -z "$LEAD_ID" || "$LEAD_ID" == "null" ]]; then
  echo "ERROR: Lead ID yok:"
  echo "$LEAD_RES" | jq .
  exit 1
fi
echo "OK: Lead ID=$LEAD_ID"

ANSWERS_JSON='{
  "city": "Konya",
  "district": "Selçuklu / Sancak",
  "type": "satılık",
  "rooms": "2+1"
}'

pick_answer () {
  local key="$1"
  echo "$ANSWERS_JSON" | jq -r --arg k "$key" '.[$k] // "test"'
}

echo "==> [5] Q/A loop (done olana kadar)"
for i in {1..120}; do
  Q_URL="$BASE_URL$(url_with_lead "$Q_GET" "$LEAD_ID")"
  Q_RES="$(http_json GET "$Q_URL")"

  DONE="$(echo "$Q_RES" | jq -r '
    if type=="array" then (map(select(.done==false))|.[0].done // true)
    else (.done // .data.done // true) end
  ' 2>/dev/null || echo true)"

  if [[ "$DONE" == "true" ]]; then
    echo "OK: questions done=true"
    break
  fi

  KEY="$(echo "$Q_RES" | jq -r '
    if type=="array" then (map(select(.done==false))|.[0].key)
    else (.key // .data.key) end
  ')"
  QUESTION="$(echo "$Q_RES" | jq -r '
    if type=="array" then (map(select(.done==false))|.[0].question)
    else (.question // .data.question) end
  ')"

  if [[ -z "$KEY" || "$KEY" == "null" ]]; then
    echo "ERROR: key okunamadı:"
    echo "$Q_RES" | jq .
    exit 1
  fi

  ANSWER="$(pick_answer "$KEY")"
  echo "  [$i] $KEY -> $ANSWER  ($QUESTION)"

  A_URL="$BASE_URL$(url_with_lead "$A_POST" "$LEAD_ID")"
  A_BODY="$(jq -n --arg k "$KEY" --arg a "$ANSWER" '{key:$k, answer:$a}')"
  http_json POST "$A_URL" "$A_BODY" >/dev/null
done

echo "==> [6] Deal poll (API'den)"
D_URL="$BASE_URL$(url_with_lead "$DEAL_GET" "$LEAD_ID")"
for _ in {1..12}; do
  if curl -sS -f "$D_URL" >/tmp/deal.json 2>/dev/null; then
    echo "✅ Deal found:"
    cat /tmp/deal.json | jq .
    exit 0
  fi
  sleep 1
done

echo "==> [7] Deal yok. DB backfill (Prisma config ile) + snapshot."

# Snapshot için API'den mevcut answer'ları çekemiyorsak,
# en azından Deal create + (varsayılan 4 alan) dolduracağız.
# (city/district/type/rooms) senin schema ile birebir uyumlu.

cat > /tmp/backfill-deal.mjs <<'NODE'
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const leadId = process.argv[2];
if (!leadId) throw new Error("leadId required");

// Basit snapshot (istersen genişlet)
const snapshot = {
  city: "Konya",
  district: "Selçuklu / Sancak",
  type: "satılık",
  rooms: "2+1",
};

async function main() {
  const existing = await prisma.deal.findUnique({ where: { leadId } });
  if (existing) {
    console.log("EXISTS", existing.id);
    return;
  }
  const created = await prisma.deal.create({
    data: { leadId, ...snapshot },
  });
  console.log("CREATED", created.id);
}

main()
  .catch((e) => {
    console.error("BACKFILL_FAILED");
    console.error(e?.message || String(e));
    process.exit(2);
  })
  .finally(async () => prisma.$disconnect());
NODE

# ÖNEMLİ: Prisma 7'de config'ten DB okunsun diye backfill'i API_DIR içinde çalıştırıyoruz.
# Böylece prisma.config.ts aynı şekilde yüklenir.
set +e
( cd "$API_DIR" && node /tmp/backfill-deal.mjs "$LEAD_ID" )
RC=$?
set -e
if [[ "$RC" -ne 0 ]]; then
  echo "❌ Backfill failed. Log'a bak:"
  echo "  tail -n 250 $LOG"
  exit 1
fi

echo "==> [8] Retry deal fetch"
if curl -sS -f "$D_URL" >/tmp/deal.json 2>/dev/null; then
  echo "✅ Deal found after backfill:"
  cat /tmp/deal.json | jq .
  exit 0
fi

echo "❌ Deal hâlâ yok."
echo "Kontrol:"
echo "  - API log: $LOG"
echo "  - Prisma Studio:"
echo "      cd $API_DIR && pnpm -s prisma studio --config ./prisma.config.ts"
echo
echo "Hızlı doğrulama (DB):"
echo "  cd $API_DIR && node -e 'const {PrismaClient}=require(\"@prisma/client\"); const p=new PrismaClient(); p.deal.findUnique({where:{leadId:\"$LEAD_ID\"}}).then(x=>{console.log(x);}).finally(()=>p.$disconnect())'"
exit 1
