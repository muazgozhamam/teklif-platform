#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"
PIDFILE="/tmp/teklif-api-dev.pid"
LOG="/tmp/teklif-api-dev.log"
BASE_URL="http://localhost:3001"
LEADS_FILE="$API_DIR/src/leads/leads.service.ts"
DIST="$API_DIR/dist"

die(){ echo "❌ $*"; exit 1; }

echo "==> 0) Konum kontrol"
[[ -d "$ROOT" ]] || die "ROOT yok: $ROOT"
[[ -d "$API_DIR" ]] || die "API_DIR yok: $API_DIR"
[[ -f "$LEADS_FILE" ]] || die "leads.service.ts yok: $LEADS_FILE"
echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo

echo "==> 1) Eski server kapat (PIDFILE + 3001)"
if [[ -f "$PIDFILE" ]]; then
  PID="$(cat "$PIDFILE" || true)"
  if [[ -n "${PID:-}" ]]; then
    echo "-> kill $PID (PIDFILE)"
    kill "$PID" 2>/dev/null || true
  fi
  rm -f "$PIDFILE" || true
fi

if command -v lsof >/dev/null 2>&1; then
  PIDS="$(lsof -ti tcp:3001 2>/dev/null || true)"
  if [[ -n "$PIDS" ]]; then
    echo "-> 3001 port kill: $PIDS"
    kill $PIDS 2>/dev/null || true
  fi
fi
echo "✅ server temiz"
echo

echo "==> 2) dist ENOTEMPTY sorunu için dist temizle"
rm -rf "$DIST" || true
mkdir -p "$DIST"
echo "✅ dist temiz"
echo

echo "==> 3) leads.service.ts nokta atışı patch (iki return satırının hemen önü)"
TS="$(date +"%Y%m%d-%H%M%S")"
cp "$LEADS_FILE" "$LEADS_FILE.bak.$TS"
echo "✅ Backup: $LEADS_FILE.bak.$TS"

python3 - <<'PY'
from pathlib import Path
import re

path = Path("/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# Prisma field adı tespit (constructor ya da kullanım üzerinden)
m_ctor = re.search(r"constructor\s*\([^)]*(?:private|public|protected)\s+(?:readonly\s+)?([a-zA-Z0-9_]+)\s*:\s*PrismaService", txt)
prisma_field = m_ctor.group(1) if m_ctor else None
if not prisma_field:
    m_use = re.search(r"\bthis\.([a-zA-Z0-9_]+)\.deal\.", txt)
    prisma_field = m_use.group(1) if m_use else None
if not prisma_field:
    raise SystemExit("❌ Prisma field adı bulunamadı (PrismaService injection yok).")

prisma_expr = f"this.{prisma_field}"

# DealStatus import garanti
m_imp = re.search(r"import\s*\{([^}]+)\}\s*from\s*['\"]@prisma/client['\"];?", txt)
if m_imp:
    items = [x.strip() for x in m_imp.group(1).split(",") if x.strip()]
    if "DealStatus" not in items:
        items.append("DealStatus")
        repl = "import { " + ", ".join(items) + " } from '@prisma/client';"
        txt = txt[:m_imp.start()] + repl + txt[m_imp.end():]
else:
    txt = "import { DealStatus } from '@prisma/client';\n" + txt

marker = "DONE_TRUE_PATCH_READY_FOR_MATCHING_V3"
targets = [
    "return { done: true, dealId: deal.id };",
    "return { ok: true, done: true, dealId: deal.id };",
]

def insert_before_exact(line: str, s: str) -> tuple[str, bool]:
    idx = s.find(line)
    if idx == -1:
        return s, False

    # line başlangıcı ve indent
    bol = s.rfind("\n", 0, idx) + 1
    indent = re.match(r"\s*", s[bol:idx]).group(0)

    # zaten var mı?
    pre = s[max(0, bol-600):bol]
    if marker in pre:
        return s, False

    inject = (
        f"{indent}// {marker}\n"
        f"{indent}await {prisma_expr}.deal.update({{\n"
        f"{indent}  where: {{ id: deal.id }},\n"
        f"{indent}  data: {{ status: DealStatus.READY_FOR_MATCHING }},\n"
        f"{indent}}});\n"
    )
    return s[:bol] + inject + s[bol:], True

patched = 0
for t in targets:
    txt, ok = insert_before_exact(t, txt)
    if ok:
        patched += 1

if patched != 2:
    raise SystemExit(f"❌ Patch eksik. patched={patched}/2. (Dosyada target satırlar farklı olabilir)")

path.write_text(txt, encoding="utf-8")
print(f"✅ Patch OK. prisma={prisma_field} patched={patched}")
PY

echo
echo "==> 4) Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
echo

echo "==> 5) API başlat (background) + health bekle"
cd "$API_DIR"
( pnpm -s start:dev >"$LOG" 2>&1 & echo $! >"$PIDFILE" )
PID="$(cat "$PIDFILE")"
echo "PID=$PID"
echo "LOG=$LOG"

ok=0
for i in {1..50}; do
  if curl -sS "$BASE_URL/health" >/dev/null 2>&1; then ok=1; break; fi
  sleep 0.2
done
[[ "$ok" -eq 1 ]] || { echo "❌ health gelmedi. Log:"; tail -n 120 "$LOG" || true; exit 1; }
curl -sS "$BASE_URL/health" | (jq || cat)
echo

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; fi

echo "==> 6) Wizard loop ile lead doldur (done olana kadar)"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "fix-ready-status-and-verify" }')"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$LEAD_JSON" | jq; else echo "$LEAD_JSON"; fi
LEAD_ID="$(echo "$LEAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
echo "LEAD_ID=$LEAD_ID"
echo

answer_for() {
  case "$1" in
    city) echo "Konya" ;;
    district) echo "Selçuklu" ;;
    type) echo "SATILIK" ;;
    rooms) echo "2+1" ;;
    *) echo "TEST" ;;
  esac
}

DEAL_ID=""
for i in {1..12}; do
  NQ="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$NQ" | jq; else echo "$NQ"; fi

  DONE="$(echo "$NQ" | python3 -c "import sys,json; print(json.load(sys.stdin).get('done', False))")"
  DEAL_ID="$(echo "$NQ" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dealId',''))")"

  if [[ "$DONE" == "True" || "$DONE" == "true" ]]; then
    echo "✅ done=true (next-question). DEAL_ID=$DEAL_ID"
    break
  fi

  FIELD="$(echo "$NQ" | python3 -c "import sys,json; print(json.load(sys.stdin)['field'])")"
  ANS="$(answer_for "$FIELD")"
  echo "-> answer field=$FIELD = '$ANS'"

  RES="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
      -H "Content-Type: application/json" \
      -d "{ \"answer\": \"$ANS\" }")"
  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$RES" | jq; else echo "$RES"; fi

  ADONE="$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('done', False))")"
  # answer response içinde dealId dönebiliyor
  DID2="$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dealId',''))")"
  if [[ -n "$DID2" ]]; then DEAL_ID="$DID2"; fi

  if [[ "$ADONE" == "True" || "$ADONE" == "true" ]]; then
    echo "✅ done=true (answer). DEAL_ID=$DEAL_ID"
    break
  fi
  echo
done

[[ -n "$DEAL_ID" ]] || { echo "❌ DEAL_ID yok. Log:"; tail -n 120 "$LOG" || true; exit 1; }
echo

echo "==> 7) Deal status doğrula (GET /deals/:id)"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/$DEAL_ID")"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$DEAL_JSON" | jq; else echo "$DEAL_JSON"; fi
STATUS="$(echo "$DEAL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status'))")"
echo "STATUS=$STATUS"
echo

echo "==> 8) Sonuç"
echo "LEAD_ID=$LEAD_ID"
echo "DEAL_ID=$DEAL_ID"
echo "STATUS=$STATUS"
echo
echo "Durdurmak için:"
echo "  kill $PID"
