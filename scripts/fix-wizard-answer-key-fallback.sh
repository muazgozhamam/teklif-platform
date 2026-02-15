#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> ROOT=$ROOT"

python3 - <<'PY'
from pathlib import Path
import re

root = Path(".").resolve()
src_root = root / "apps" / "api" / "src"

def backup_write(p: Path, new_txt: str, suffix: str):
    bak = p.with_suffix(p.suffix + suffix)
    if not bak.exists():
        bak.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
    p.write_text(new_txt, encoding="utf-8")
    return bak

# 1) Patch DTO: make key optional if validation currently requires it
candidates = []
for p in src_root.rglob("*.ts"):
    try:
        txt = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if "key is required" in txt:
        candidates.append(p)

if not candidates:
    raise SystemExit("❌ Could not find any TS file containing 'key is required' under apps/api/src")

dto_patched = False
for p in candidates:
    txt = p.read_text(encoding="utf-8")

    # Heuristic: must look like a DTO with key field
    if not re.search(r"\bkey\s*:\s*string\b|\bkey\s*;\b", txt):
        continue

    new = txt

    # Ensure IsOptional imported (best-effort)
    if "IsOptional" not in new:
        new = re.sub(
            r"(from\s+'class-validator';)",
            lambda m: m.group(0),  # leave line; we’ll patch named import below
            new,
            count=1
        )
        # Patch named import list: import { ..., IsNotEmpty, ... } from 'class-validator';
        new2, n = re.subn(
            r"import\s*\{\s*([^}]+)\s*\}\s*from\s*'class-validator';",
            lambda m: "import { " + (m.group(1).strip() + ", IsOptional") + " } from 'class-validator';"
            if "IsOptional" not in m.group(1) else m.group(0),
            new,
            count=1
        )
        if n:
            new = new2

    # Replace IsNotEmpty message for key with IsOptional (covers common patterns)
    new = re.sub(
        r"@IsNotEmpty\(\s*\{\s*message\s*:\s*['\"]key is required['\"]\s*\}\s*\)\s*",
        "@IsOptional()\n",
        new
    )
    # If key has a plain @IsNotEmpty() directly above it, also relax it (only when near key)
    new = re.sub(
        r"(@IsNotEmpty\(\)\s*\n)(\s*@IsString\(\)\s*\n\s*)?(\s*key\s*:\s*string\s*;)",
        lambda m: "@IsOptional()\n" + (m.group(2) or "") + "  key?: string;\n",
        new,
        flags=re.M
    )

    # If still has `key: string;` convert to optional (best-effort, only inside class)
    new = re.sub(r"^\s*key\s*:\s*string\s*;\s*$", "  key?: string;", new, flags=re.M)

    if new != txt:
        bak = backup_write(p, new, ".keyoptional.bak")
        print(f"✅ DTO patched: {p}")
        print(f" - backup: {bak.name}")
        dto_patched = True
        break

if not dto_patched:
    print("⚠️ No DTO patch applied (pattern mismatch). Continuing to controller fallback patch.")

# 2) Patch controller: fallback key from field for wizard/answer handler
# Find controller file that contains "/wizard/answer"
ctrl_files = []
for p in src_root.rglob("*.controller.ts"):
    try:
        txt = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if "wizard/answer" in txt:
        ctrl_files.append(p)

if not ctrl_files:
    raise SystemExit("❌ Could not find any *.controller.ts containing 'wizard/answer'")

ctrl_patched = False
for p in ctrl_files:
    txt = p.read_text(encoding="utf-8")

    # Insert a fallback line in the handler that receives dto
    # We look for a method body that mentions wizard/answer OR wizardAnswer and has a dto param
    # Then we inject: dto.key = dto.key ?? (dto as any).field;
    inject_line = "    dto.key = dto.key ?? (dto as any).field;\n"

    # Case A: handler already has dto variable in scope; inject right after opening brace of method
    m = re.search(r"(wizard.*answer[\s\S]{0,4000}\{)", txt, flags=re.I)
    if not m:
        m = re.search(r"(\bwizardAnswer\b[\s\S]{0,2000}\{)", txt, flags=re.I)
    if not m:
        continue

    # Avoid double insert
    if "dto.key = dto.key ??" in txt:
        print(f"✅ Controller already has fallback: {p}")
        ctrl_patched = True
        break

    # Inject after the first "{" of the matched method block
    start = m.end(1)
    new = txt[:start] + "\n" + inject_line + txt[start:]

    bak = backup_write(p, new, ".keyfallback.bak")
    print(f"✅ Controller patched: {p}")
    print(f" - backup: {bak.name}")
    ctrl_patched = True
    break

if not ctrl_patched:
    raise SystemExit("❌ Could not patch controller fallback (pattern mismatch).")

print("✅ Patch complete. Restart API and re-run smoke.")
PY

echo "==> DONE. Now restart your API (pnpm -C apps/api start:dev) and re-run smoke."
