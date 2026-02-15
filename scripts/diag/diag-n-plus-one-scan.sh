#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="$ROOT_DIR/apps/api/src"

if ! command -v rg >/dev/null 2>&1; then
  echo "❌ rg is required"
  exit 1
fi

echo "==> diag-n-plus-one-scan"
echo "TARGET_DIR=$TARGET_DIR"

# Heuristic: detect loops containing direct prisma awaits.
# This is a best-effort static signal, not a parser.
HITS="$(rg -n "for \(.*\).*\n[[:space:]]*.*await[[:space:]]+this\.prisma|forEach\(.*=>[[:space:]]*.*await[[:space:]]+this\.prisma" "$TARGET_DIR" --glob "*.ts" -U || true)"

if [ -n "$HITS" ]; then
  echo "⚠️ Potential N+1 patterns found:"
  echo "$HITS"
  echo "⚠️ Review required (script does not fail by default)."
  exit 0
fi

echo "✅ No obvious per-item prisma await loops found"
