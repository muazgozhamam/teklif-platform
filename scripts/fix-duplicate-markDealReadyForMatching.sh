#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "FILE=$FILE"
[[ -f "$FILE" ]] || { echo "❌ File not found: $FILE"; exit 1; }

TS="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"

python3 - <<'PY'
from pathlib import Path
import re

file_path = Path("apps/api/src/leads/leads.service.ts")
txt = file_path.read_text(encoding="utf-8")

# MarkDealReadyForMatching method blocks (simple but robust enough for this case)
pat = re.compile(
    r"\n\s*private\s+async\s+markDealReadyForMatching\s*\(\s*dealId\s*:\s*string\s*\)\s*\{\s*[\s\S]*?\n\s*\}\s*\n",
    re.MULTILINE
)

matches = list(pat.finditer(txt))
if len(matches) <= 1:
    print(f"ℹ️ No duplicates found (count={len(matches)}). Nothing to do.")
else:
    # keep the first, remove the rest
    keep = matches[0]
    parts = []
    last = 0
    removed = 0
    for i, m in enumerate(matches):
        if i == 0:
            continue
        # remove block m
        parts.append(txt[last:m.start()])
        last = m.end()
        removed += 1
    parts.append(txt[last:])
    # Reconstruct with the first kept implicitly in the non-removed regions:
    # BUT the first block is still present in txt; we removed only later blocks.
    new_txt = "".join(parts)

    # sanity: ensure exactly 1 remains
    if len(list(pat.finditer(new_txt))) != 1:
        raise SystemExit("❌ Cleanup failed: expected exactly 1 markDealReadyForMatching after removal.")
    txt = new_txt
    print(f"✅ Removed duplicates: {removed} block(s)")

file_path.write_text(txt, encoding="utf-8")
PY

echo
echo "==> Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
