#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

if [ ! -f "$ROOT/pnpm-workspace.yaml" ]; then
  echo "❌ Repo root bulunamadı (pnpm-workspace.yaml yok). ROOT=$ROOT"
  exit 1
fi

FILE="$ROOT/apps/api/src/leads/leads.controller.ts"
if [ ! -f "$FILE" ]; then
  echo "❌ Missing: $FILE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/leads.controller.ts")
txt = p.read_text(encoding="utf-8")
orig = txt

# 1) Remove WizardAnswerDto from import list
# e.g. import { LeadAnswerDto, WizardAnswerDto } from './dto/lead-answer.dto';
txt = re.sub(
    r"import\s*\{\s*([^}]+)\s*\}\s*from\s*['\"]\.\/dto\/lead-answer\.dto['\"]\s*;\s*",
    lambda m: (
        "import { " + ", ".join(
            [x.strip() for x in m.group(1).split(",") if x.strip() and x.strip() != "WizardAnswerDto"]
        ) + " } from './dto/lead-answer.dto';\n"
        if "WizardAnswerDto" in m.group(1) else m.group(0)
    ),
    txt,
    count=1,
)

# 2) If WizardAnswerDto is used as a type anywhere in this controller, replace with LeadAnswerDto
txt = re.sub(r"\bWizardAnswerDto\b", "LeadAnswerDto", txt)

if txt == orig:
    raise SystemExit("❌ No changes applied (WizardAnswerDto not found?)")

bak = p.with_suffix(p.suffix + ".wizarddtofix.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Patched controller: removed WizardAnswerDto import + replaced usages with LeadAnswerDto")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Build API (typecheck)"
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Done."
