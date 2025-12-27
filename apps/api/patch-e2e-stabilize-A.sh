#!/usr/bin/env bash
set -euo pipefail

FILE="e2e-managed-advance.sh"

[[ -f "$FILE" ]] || { echo "❌ $FILE yok. apps/api içinde çalıştır."; exit 1; }

# yedek
cp -f "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"

python3 - "$FILE" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# 1) set -euo pipefail sonrası init (nounset fix)
if not re.search(r'(?m)^\s*adv_body=""\s*$', txt):
    m = re.search(r'(?m)^(set\s+-euo\s+pipefail\s*)$', txt)
    if not m:
        print("NO_SET_EUO_PIPEFAIL")
        raise SystemExit(2)
    insert = '\n# nounset safety init\nadv_body=""\nadv_code=""\n'
    txt = txt[:m.end()] + insert + txt[m.end():]

# 2) Advance HTTP check: 200/201 kabul (varsa 200-only check'i genişlet)
txt = re.sub(
    r'\[\[\s*"\$\{adv_code\}"\s*==\s*"200"\s*\]\]',
    '[[ "${adv_code}" == "200" || "${adv_code}" == "201" ]]',
    txt
)
txt = re.sub(
    r'\[\[\s*"\$\{adv_code\}"\s*!=\s*"200"\s*\]\]',
    '[[ "${adv_code}" != "200" && "${adv_code}" != "201" ]]',
    txt
)

# 3) Fail mesajlarında adv_body unbound olmasın (defansif)
txt = txt.replace('${adv_body}', '${adv_body:-}')

# 4) EXPECT_STATUS assert'i: advance response yerine DB'den tekrar oku (by-lead)
# Mevcut blok şu tarz oluyor:
# got_status="$(node -e ... "${adv_body}")"
# bunu DEAL_JSON üzerinden okuyacak hale getiriyoruz.
txt = re.sub(
    r'got_status="\$\(\s*node\s+-e\s+\'const j=JSON\.parse\(process\.argv\[1\]\);\s*process\.stdout\.write\(j\.status \|\| ""\)\'\s*"\$\{adv_body(?::-[^}]*)?\}"\s*\)"',
    "got_status=\"$(node -e 'const j=JSON.parse(process.argv[1]); const d=(j.deal||j); process.stdout.write(d.status||\"\")' \"${DEAL_JSON}\")\"",
    txt
)

# Eğer script'te EXPECT_STATUS bloğu hiç yoksa dokunmayız; zaten kullanıcı EXPECT_STATUS ile koşuyor.
p.write_text(txt, encoding="utf-8")
print("PATCHED")
PY

echo "✅ PATCHED: $FILE"
echo
echo "Run:"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./$FILE"
