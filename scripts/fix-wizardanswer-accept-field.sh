#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
API="$ROOT/apps/api"

python3 - <<'PY'
from pathlib import Path
import re, sys

ROOT = Path(".").resolve()
API = ROOT / "apps" / "api"

# 1) Find a DTO file that defines Wizard Answer DTO with "key"
candidates = []
for p in API.rglob("*.ts"):
    s = str(p)
    if "/dist/" in s or "/node_modules/" in s:
        continue
    txt = p.read_text(encoding="utf-8", errors="ignore")
    if re.search(r"\bclass\s+\w*(Wizard)?\w*Answer\w*Dto\b", txt) and re.search(r"\bkey\s*:\s*string\b", txt):
        candidates.append(p)

if not candidates:
    print("❌ Could not find Wizard Answer DTO file containing `key: string`.")
    sys.exit(1)

dto = candidates[0]
txt = dto.read_text(encoding="utf-8")

orig = txt

# Ensure IsOptional import
if "IsOptional" not in txt:
    # add to existing class-validator import
    m = re.search(r"from\s+['\"]class-validator['\"];\s*$", txt, flags=re.M)
    if m:
        # Find the import line start
        line_start = txt.rfind("\n", 0, m.start()) + 1
        line_end = txt.find("\n", line_start)
        line = txt[line_start:line_end]
        # If it's a named import: import { A, B } from 'class-validator';
        m2 = re.match(r"\s*import\s*\{\s*([^}]+)\s*\}\s*from\s*['\"]class-validator['\"]\s*;\s*$", line)
        if m2:
            names = [x.strip() for x in m2.group(1).split(",") if x.strip()]
            if "IsOptional" not in names:
                names.append("IsOptional")
            new_line = "import { " + ", ".join(sorted(set(names))) + " } from 'class-validator';"
            txt = txt[:line_start] + new_line + txt[line_end:]
    else:
        # fallback: add a new import
        txt = "import { IsOptional } from 'class-validator';\n" + txt

# Make key optional + add IsOptional decorator (if not already)
# pattern tolerates decorators above key
# If already key?: string, keep
if re.search(r"\bkey\s*\?:\s*string\b", txt) is None:
    # Replace `key: string;` with `key?: string;`
    txt = re.sub(r"(\bkey\s*):\s*string\b", r"\1?: string", txt, count=1)

# Ensure @IsOptional above key
if "@IsOptional()" not in re.search(r"([\s\S]{0,300})\bkey\s*\??:\s*string", txt).group(1):
    txt = re.sub(
        r"(\n\s*)(@IsString\(\)\s*\n\s*)?(\bkey\s*\??:\s*string)",
        r"\1@IsOptional()\n\1@IsString()\n\1\3",
        txt,
        count=1
    )

# Add field optional string if missing
if re.search(r"\bfield\s*\??:\s*string\b", txt) is None:
    # insert right after key line block
    m = re.search(r"(\bkey\s*\??:\s*string\s*;\s*)", txt)
    if not m:
        print("❌ Could not locate key property to insert field next to it.")
        sys.exit(1)
    insert_pos = m.end(1)
    # determine indentation of the key line
    line_start = txt.rfind("\n", 0, m.start()) + 1
    indent = re.match(r"\s*", txt[line_start:m.start()]).group(0)
    field_block = (
        f"\n{indent}@IsOptional()\n"
        f"{indent}@IsString()\n"
        f"{indent}field?: string;\n"
    )
    txt = txt[:insert_pos] + field_block + txt[insert_pos:]

if txt == orig:
    print("✅ DTO already compatible (no changes).", dto)
else:
    bak = dto.with_suffix(dto.suffix + ".acceptfield.bak")
    bak.write_text(orig, encoding="utf-8")
    dto.write_text(txt, encoding="utf-8")
    print("✅ Patched DTO to accept key OR field:")
    print(" - Updated:", dto)
    print(" - Backup :", bak)

# 2) Patch service to use key ?? field (so even if key missing, it works)
svc = API / "src" / "leads" / "leads.service.ts"
if not svc.exists():
    print("⚠️ leads.service.ts not found at expected path:", svc)
    sys.exit(0)

svctxt = svc.read_text(encoding="utf-8")
svcorig = svctxt

# Replace common usages dto.key with (dto.key ?? (dto as any).field)
# but avoid double replacing
if "dto.key ?? (dto as any).field" not in svctxt:
    svctxt = re.sub(r"\bdto\.key\b", r"(dto.key ?? (dto as any).field)", svctxt)

if svctxt != svcorig:
    bak = svc.with_suffix(".ts.acceptfield.bak")
    bak.write_text(svcorig, encoding="utf-8")
    svc.write_text(svctxt, encoding="utf-8")
    print("✅ Patched leads.service.ts to read key||field (backup:", bak.name + ")")
else:
    print("✅ leads.service.ts already compatible (no changes).")
PY

echo "==> Restart API + smoke"
bash scripts/free-port-3001.sh
( pnpm -C apps/api start:dev >/tmp/api-dev.log 2>&1 & )
for i in {1..80}; do curl -fsS http://localhost:3001/health >/dev/null && break; sleep 0.25; done
curl -fsS http://localhost:3001/health && echo
bash scripts/smoke-wizard-to-match-mac.sh | sed -n '1,260p' || (echo; echo "---- api log (last 140) ----"; tail -n 140 /tmp/api-dev.log)
