#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
SRC="$ROOT/apps/api/src/leads/leads.service.ts"
DIST="$ROOT/apps/api/dist/src/leads/leads.service.js"

echo "==> 0) Paths"
echo "SRC : $SRC"
echo "DIST: $DIST"
[[ -f "$SRC" ]] || { echo "❌ Missing SRC"; exit 2; }

echo
echo "==> 1) Check SRC contains markers"
if rg -n "WIZPERS_|WIZARD_DEAL_UPSERT_PERSIST_V1|WIZARD_DEAL_UPSERT_PERSIST_V2|WIZARD_DEAL_UPSERT_PERSIST" "$SRC" >/dev/null 2>&1; then
  echo "OK: SRC has marker(s)"
  rg -n "WIZPERS_|WIZARD_DEAL_UPSERT_PERSIST_V1|WIZARD_DEAL_UPSERT_PERSIST_V2|WIZARD_DEAL_UPSERT_PERSIST" "$SRC" || true
else
  echo "❌ SRC has NO marker. (Patch is not in source file you think.)"
fi

echo
echo "==> 2) Build API dist"
pnpm -s -C apps/api build

echo
echo "==> 3) Check DIST exists"
[[ -f "$DIST" ]] || { echo "❌ Missing DIST file: $DIST"; exit 3; }

echo
echo "==> 4) Check DIST contains markers"
if rg -n "WIZPERS_|WIZARD_DEAL_UPSERT_PERSIST" "$DIST" >/dev/null 2>&1; then
  echo "OK: DIST has marker(s)"
  rg -n "WIZPERS_|WIZARD_DEAL_UPSERT_PERSIST" "$DIST" || true

  echo
  echo "==> 5) Show context around first marker in DIST"
  LINE="$(rg -n "WIZPERS_|WIZARD_DEAL_UPSERT_PERSIST" "$DIST" | head -n 1 | cut -d: -f1)"
  START=$((LINE-20)); if [ "$START" -lt 1 ]; then START=1; fi
  END=$((LINE+60))
  nl -ba "$DIST" | sed -n "${START},${END}p"
else
  echo "❌ DIST has NO marker. (Your running code cannot log WIZPERS and cannot persist.)"
  echo "HINT: This means build output is coming from a different TS file or the patch is not in the compiled path."
fi

echo
echo "==> DONE"
