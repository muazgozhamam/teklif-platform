#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIR="$ROOT/scripts/sprint-next"
TS="$(date +"%Y%m%d-%H%M%S")"
ARCH="$DIR/_archive/$TS"

mkdir -p "$ARCH"

echo "==> ROOT=$ROOT"
echo "==> ARCHIVE=$ARCH"
echo

# Keep only these as "final / active"
KEEP=(
  "05-start-api-dev-3001.sh"
  "11-fix-api-dist-enotempty-build.sh"
  "36-smoke-listings-pagination.sh"
  "46-fix-default-consultant-on-listing-create-and-run-pagination-smoke.sh"
  "52-fix-listings-list-method-parse-safe-and-run.sh"
  "64-fix-listings-controller-list-body-forward-query-and-run.sh"
  "65-finalize-pagination-sprint-snapshot.sh"
  "66-archive-noisy-sprint-scripts-keep-finals.sh"
)

keep_set="|"
for k in "${KEEP[@]}"; do keep_set+="$k|"; done

echo "==> 1) Archiving non-final scripts from $DIR"
moved=0

shopt -s nullglob
for f in "$DIR"/*.sh; do
  base="$(basename "$f")"
  # Skip keep list and any archive runner
  if [[ "$keep_set" == *"|$base|"* ]]; then
    continue
  fi

  # Never move anything under _archive
  if [[ "$f" == *"/_archive/"* ]]; then
    continue
  fi

  mv "$f" "$ARCH/"
  moved=$((moved+1))
done
shopt -u nullglob

echo "   - Moved: $moved file(s)"
echo

echo "==> 2) What remains in scripts/sprint-next (top-level)"
ls -1 "$DIR" | sed 's/^/   - /' || true
echo

echo "==> 3) Archive contents"
ls -1 "$ARCH" | sed 's/^/   - /' || true
echo

echo "==> 4) git status"
cd "$ROOT"
git status --porcelain || true
echo

echo "✅ Archive complete."
