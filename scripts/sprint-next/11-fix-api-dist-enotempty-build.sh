#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

API_DIR="apps/api"
DIST="$API_DIR/dist"
LOG=".tmp/api-dev-3001.log"

echo "==> ROOT: $(pwd)"
echo "==> API_DIR=$API_DIR"

echo
echo "==> 1) Node süreçlerini (apps/api altında çalışan) güvenli kapat"
# start:dev genelde "node" ve "ts-node/webpack" processleri bırakır.
# Sadece repo içindeki apps/api path'ine referans verenleri hedef alıyoruz.
PIDS="$(ps aux | rg "$API_DIR" | rg -v "rg " | awk '{print $2}' || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PIDs: ${PIDS}"
  kill -9 ${PIDS} || true
else
  echo "   - apps/api 관련 node process yok"
fi

echo
echo "==> 2) dist klasörünü zorla temizle"
if [ -d "$DIST" ]; then
  # önce rename (macos'ta kilitli dosyalarda işe yarar)
  TS="$(date +%Y%m%d-%H%M%S)"
  TMP="${DIST}.old.${TS}"
  echo "   - Renaming dist -> $TMP"
  mv "$DIST" "$TMP" || true
  echo "   - Removing $TMP"
  rm -rf "$TMP" || true
fi
mkdir -p "$DIST" || true
rm -rf "$DIST" || true

echo
echo "==> 3) Build"
cd "$API_DIR"
pnpm -s build

echo
echo "✅ ADIM 11 TAMAM: build OK"
echo "Not: Dev server kapandıysa tekrar başlatman gerekir."
