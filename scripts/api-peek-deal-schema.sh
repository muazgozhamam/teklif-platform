#!/usr/bin/env bash
set -euo pipefail

SCHEMA="apps/api/prisma/schema.prisma"
if [[ ! -f "$SCHEMA" ]]; then
  echo "❌ Bulunamadı: $SCHEMA"
  exit 1
fi

echo "==> enum DealStatus (varsa)"
grep -n "enum DealStatus" -n "$SCHEMA" || true
LINE="$(grep -n "enum DealStatus" "$SCHEMA" | head -n1 | cut -d: -f1 || true)"
if [[ -n "${LINE:-}" ]]; then
  START=$((LINE)); END=$((LINE+80))
  nl -ba "$SCHEMA" | sed -n "${START},${END}p"
fi
echo

echo "==> model Deal"
LINE2="$(grep -n "^model Deal" "$SCHEMA" | head -n1 | cut -d: -f1 || true)"
if [[ -z "${LINE2:-}" ]]; then
  echo "❌ model Deal bulunamadı"
  exit 1
fi
START2=$((LINE2)); END2=$((LINE2+140))
nl -ba "$SCHEMA" | sed -n "${START2},${END2}p"

echo
echo "✅ DONE. Çıktıyı buraya yapıştır."
