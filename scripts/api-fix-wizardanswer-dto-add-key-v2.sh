#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FILE="apps/api/src/leads/dto/lead-answer.dto.ts"

echo "==> Repo: $ROOT"
if [[ ! -f "$FILE" ]]; then
  echo "❌ Bulunamadı: $FILE"
  exit 1
fi

python3 - "$FILE" <<'PY'
import re, sys, pathlib

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

m = re.search(r"(export\s+class\s+WizardAnswerDto\s*\{)([\s\S]*?)(\n\})", txt)
if not m:
    raise SystemExit("❌ export class WizardAnswerDto bloğu bulunamadı (dosya formatı farklı).")

body = m.group(2)

# zaten varsa çık
if re.search(r"\bkey\s*\??\s*:\s*string\b", body):
    print("✅ key zaten var:", p)
    raise SystemExit(0)

# class içine, answer'dan önce ekle (answer yoksa başa ekle)
if re.search(r"\banswer\s*\??\s*:\s*string\b", body):
    body2 = re.sub(r"(\banswer\s*\??\s*:\s*string\s*;?)", r"key?: string;\n  \1", body, count=1)
else:
    body2 = "  key?: string;\n" + body

out = txt[:m.start(2)] + body2 + txt[m.end(2):]
p.write_text(out, encoding="utf-8")
print("✅ Patched WizardAnswerDto (key eklendi):", p)
PY

echo "✅ DONE."
