#!/usr/bin/env bash
set -euo pipefail

CTRL="apps/api/src/deals/deals.controller.ts"
SVC="apps/api/src/deals/deals.service.ts"

echo "==> deals.controller.ts: by-lead route"
LINE="$(grep -n "by-lead" "$CTRL" | head -n1 | cut -d: -f1 || true)"
if [[ -z "${LINE:-}" ]]; then
  echo "❌ controller içinde by-lead bulunamadı: $CTRL"
  exit 1
fi
START=$((LINE-8)); if (( START < 1 )); then START=1; fi
END=$((LINE+40))
nl -ba "$CTRL" | sed -n "${START},${END}p"
echo

echo "==> deals.service.ts: byLead method (findFirst/findUnique kısmı)"
# by-lead handler hangi service metodunu çağırıyorsa onu yakalamak için "byLead" ve "leadId" arıyoruz
LINE2="$(grep -n -E "byLead|by-lead|leadId" "$SVC" | head -n1 | cut -d: -f1 || true)"
if [[ -z "${LINE2:-}" ]]; then
  echo "❌ service içinde leadId ile ilgili blok bulunamadı: $SVC"
  exit 1
fi
START2=$((LINE2-10)); if (( START2 < 1 )); then START2=1; fi
END2=$((LINE2+120))
nl -ba "$SVC" | sed -n "${START2},${END2}p"

echo
echo "✅ DONE. Çıktıyı buraya yapıştır."
