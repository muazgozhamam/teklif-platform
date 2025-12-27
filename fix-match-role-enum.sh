#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SVC="$API_DIR/src/deals/deals.service.ts"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -f "$SVC" ]] || die "DealsService yok: $SVC"

say "0) Backup"
cp -f "$SVC" "$SVC.bak.$(date +%Y%m%d-%H%M%S)"

say "1) Role enum import et (yoksa) + role filter'ı Role.CONSULTANT yap"
python3 - "$SVC" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")
orig = txt

# 1) Import: PrismaService importu genelde var. @prisma/client importu yoksa ekle.
# Zaten varsa içine Role ekle.
if re.search(r"from\s+'@prisma/client'", txt):
    # Var: Role yoksa ekle
    def add_role(m):
        s = m.group(0)
        if "Role" in s:
            return s
        # import { X } -> import { X, Role }
        s2 = re.sub(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*'@prisma/client';",
                    lambda mm: "import { " + mm.group(1).strip() + ", Role } from '@prisma/client';",
                    s)
        return s2
    txt = re.sub(r"import\s*\{\s*[^}]+\s*\}\s*from\s*'@prisma/client';", add_role, txt, count=1)
else:
    # Yok: en üste ekle (ilk import satırının önüne)
    m = re.search(r"(?m)^\s*import\s+", txt)
    ins = "import { Role } from '@prisma/client';\n"
    if m:
        txt = txt[:m.start()] + ins + txt[m.start():]
    else:
        txt = ins + txt

# 2) findFirst where role: "CONSULTANT" -> role: Role.CONSULTANT
txt = re.sub(r'role:\s*"CONSULTANT"\s+as\s+any', 'role: Role.CONSULTANT', txt)
txt = re.sub(r'role:\s*"CONSULTANT"', 'role: Role.CONSULTANT', txt)

# 3) Eğer hâlâ any cast varsa temizle (çok agresif olmadan)
txt = txt.replace('{ role: Role.CONSULTANT } as any', '{ role: Role.CONSULTANT }')

if txt == orig:
    print("NO_CHANGE (pattern yakalanmadı)")
    raise SystemExit(2)

p.write_text(txt, encoding="utf-8")
print("PATCHED")
PY

say "2) Build"
cd "$API_DIR"
pnpm -s build

say "✅ DONE"
echo
echo "Not: Çalışan API dist modundaysa restart etmen gerekir."
