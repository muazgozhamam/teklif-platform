#!/usr/bin/env bash
set -euo pipefail

[ -d "dist" ] || { echo "HATA: dist yok. Önce pnpm -s build"; exit 1; }

echo "==> 1) dist içinde main.js nerede?"
find dist -maxdepth 3 -name "main.js" -print

echo
echo "==> 2) dist içinde app.module.js nerede?"
find dist -maxdepth 4 -name "app.module.js" -print

echo
echo "==> 3) dist içinde DealsController/DealsService stringi aranıyor"
grep -R --line-number --fixed-strings "DealsController" dist || true
grep -R --line-number --fixed-strings "DealsService" dist || true

echo
echo "==> 4) dist app.module.js içinde controllers/providers/imports snapshot (bulabilirsek)"
APPJS="$(find dist -maxdepth 4 -name "app.module.js" | head -n 1 || true)"
if [ -n "$APPJS" ]; then
  echo "--- $APPJS (ilk 220 satır) ---"
  sed -n '1,220p' "$APPJS"
  echo "----------------------------"
else
  echo "UYARI: app.module.js bulunamadı."
fi

echo
echo "==> DONE"
