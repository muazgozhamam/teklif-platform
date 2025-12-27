#!/usr/bin/env bash
set -euo pipefail

echo "==> 1) leads.controller.ts: wizard/answer handler (yakın çevre)"
CTRL="apps/api/src/leads/leads.controller.ts"
if [[ ! -f "$CTRL" ]]; then
  echo "❌ Bulunamadı: $CTRL"
  exit 1
fi

LINE="$(grep -n "@Post(':id/wizard/answer')" "$CTRL" | head -n1 | cut -d: -f1 || true)"
if [[ -z "${LINE:-}" ]]; then
  echo "❌ @Post(':id/wizard/answer') bulunamadı"
  exit 1
fi
START=$((LINE-5)); if (( START < 1 )); then START=1; fi
END=$((LINE+45))
nl -ba "$CTRL" | sed -n "${START},${END}p"
echo

echo "==> 2) leads.service.ts: wizardAnswer() method (yakın çevre)"
SVC="apps/api/src/leads/leads.service.ts"
if [[ ! -f "$SVC" ]]; then
  echo "❌ Bulunamadı: $SVC"
  exit 1
fi

LINE2="$(grep -n "async wizardAnswer" "$SVC" | head -n1 | cut -d: -f1 || true)"
if [[ -z "${LINE2:-}" ]]; then
  echo "❌ async wizardAnswer bulunamadı"
  exit 1
fi
START2=$((LINE2-5)); if (( START2 < 1 )); then START2=1; fi
END2=$((LINE2+140))
nl -ba "$SVC" | sed -n "${START2},${END2}p"
echo

echo "✅ DONE. Bu çıktıyı buraya yapıştır."
