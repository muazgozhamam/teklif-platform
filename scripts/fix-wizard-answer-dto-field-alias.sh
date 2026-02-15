#!/usr/bin/env bash
set -euo pipefail

# --- Resolve repo root (works from anywhere) ---
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

if [ ! -f "$ROOT/pnpm-workspace.yaml" ]; then
  echo "❌ Could not locate repo root (pnpm-workspace.yaml not found)."
  echo "   Script location: $SELF_DIR"
  echo "   Expected root:   $ROOT"
  exit 1
fi

API_DIR="$ROOT/apps/api"
if [ ! -d "$API_DIR" ]; then
  echo "❌ Missing apps/api at: $API_DIR"
  exit 1
fi

echo "==> ROOT=$ROOT"

python3 - <<'PY'
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve()
# NOTE: __file__ inside heredoc python is <stdin>; so we rely on cwd being repo root via bash
root = Path.cwd()

dto_candidates = [
    root / "apps/api/src/leads/dto/lead-answer.dto.ts",
    root / "apps/api/src/leads/dto/lead-answer.dto.ts".replace("\\", "/"),
    root / "apps/api/src/leads/dto/lead-answer.dto.ts".replace("\\", "/"),
    root / "apps/api/src/leads/dto/lead-answer.dto.ts",
    root / "apps/api/src/leads/dto/lead-answer.dto.ts",
]
# Also scan if the dto moved
scan = list((root / "apps/api/src").rglob("lead-answer.dto.ts"))
dto_path = scan[0] if scan else None

if dto_path is None or not dto_path.exists():
    raise SystemExit("❌ Could not find lead-answer.dto.ts under apps/api/src")

txt = dto_path.read_text(encoding="utf-8")
orig = txt

# --- Ensure imports: IsString, IsNotEmpty, IsOptional and Transform ---
# class-validator imports
m = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*'class-validator'\s*;", txt)
if not m:
    raise SystemExit("❌ Could not find class-validator import in DTO.")
items = [x.strip() for x in m.group(1).split(",") if x.strip()]
needed = ["IsString", "IsNotEmpty", "IsOptional"]
for n in needed:
    if n not in items:
        items.append(n)
items_sorted = items  # keep stable-ish order
new_cv = "import { " + ", ".join(items_sorted) + " } from 'class-validator';"
txt = txt[:m.start()] + new_cv + txt[m.end():]

# class-transformer Transform import
if "from 'class-transformer'" not in txt:
    # insert after class-validator import line
    txt = re.sub(
        r"(import\s*\{[^}]+\}\s*from\s*'class-validator'\s*;\s*)",
        r"\1import { Transform } from 'class-transformer';\n",
        txt,
        count=1,
    )
else:
    # ensure Transform is in the import list
    m2 = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*'class-transformer'\s*;", txt)
    if m2:
        it2 = [x.strip() for x in m2.group(1).split(",") if x.strip()]
        if "Transform" not in it2:
            it2.append("Transform")
        new_ct = "import { " + ", ".join(it2) + " } from 'class-transformer';"
        txt = txt[:m2.start()] + new_ct + txt[m2.end():]

# --- Patch class fields to support both key and field ---
# Strategy:
# - keep `key` validated (required)
# - but Transform key to fallback to obj.field
# - allow `field` as optional string (so callers can send it, but it is not required)
#
# We look for property blocks for key/answer/field and rewrite them deterministically.

# Find class block
cm = re.search(r"export\s+class\s+\w+\s*\{([\s\S]*)\}\s*$", txt, re.M)
if not cm:
    raise SystemExit("❌ Could not find DTO class declaration.")

body = cm.group(1)

# Remove existing key/field definitions (keep other fields)
# We'll remove any property named key or field with decorators above it.
def strip_prop(src: str, name: str) -> str:
    # decorators + optional whitespace + name line + maybe initializer + newline
    pattern = re.compile(rf"(?:\s*@[\s\S]*?\n)*\s*{name}\s*\??\s*:\s*[^;]+;\s*\n", re.M)
    return re.sub(pattern, "", src)

body2 = strip_prop(body, "key")
body2 = strip_prop(body2, "field")

# Ensure answer prop exists; if not, we will not guess.
if re.search(r"\banswer\s*\??\s*:", body2) is None:
    # If it was removed accidentally or not present, fail loudly.
    raise SystemExit("❌ DTO does not seem to contain an `answer` property; aborting to avoid breaking API.")

# Insert new key/field props near top of class (before first property)
insert_block = """
  // Accept both `key` and legacy/alternate `field`.
  // If `field` is provided, it is mapped into `key` during transform stage (before validation).
  @Transform(({ value, obj }) => value ?? obj?.field)
  @IsString()
  @IsNotEmpty()
  key: string;

  @IsOptional()
  @IsString()
  field?: string;
""".lstrip("\n")

# Place right after opening brace new line
new_body = insert_block + "\n" + body2.lstrip()

txt = txt[:cm.start(1)] + new_body + txt[cm.end(1):]

if txt == orig:
    raise SystemExit("❌ No changes applied (unexpected).")

bak = dto_path.with_suffix(dto_path.suffix + ".fieldalias.bak")
bak.write_text(orig, encoding="utf-8")
dto_path.write_text(txt, encoding="utf-8")

print("✅ Patched DTO to accept both key+field via Transform (and fixed imports)")
print(" - Updated:", dto_path)
print(" - Backup :", bak)

# --- Ensure ValidationPipe transform:true in main.ts (required for Transform to run) ---
main_candidates = list((root / "apps/api/src").rglob("main.ts"))
if not main_candidates:
    raise SystemExit("❌ Could not find apps/api/src/main.ts")
main_path = main_candidates[0]
mtxt = main_path.read_text(encoding="utf-8")
morig = mtxt

# Heuristic: find new ValidationPipe({ ... })
vp = re.search(r"new\s+ValidationPipe\s*\(\s*\{([\s\S]*?)\}\s*\)", mtxt)
if vp:
    opts = vp.group(1)
    if re.search(r"\btransform\s*:", opts) is None:
        # add transform: true near top of options
        new_opts = "transform: true,\n" + opts.lstrip()
        mtxt = mtxt[:vp.start(1)] + new_opts + mtxt[vp.end(1):]
else:
    # If ValidationPipe call is not object-literal style, we won't try to rewrite aggressively.
    # Just warn.
    print("⚠️  Could not locate object-literal ValidationPipe options in main.ts; skipping transform:true injection.")
    mtxt = morig

if mtxt != morig:
    mbak = main_path.with_suffix(main_path.suffix + ".transformtrue.bak")
    mbak.write_text(morig, encoding="utf-8")
    main_path.write_text(mtxt, encoding="utf-8")
    print("✅ Ensured ValidationPipe has transform:true")
    print(" - Updated:", main_path)
    print(" - Backup :", mbak)
else:
    print("ℹ️  main.ts unchanged (transform:true already present or pattern not found).")
PY

echo
echo "==> Build API (typecheck)"
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Done."
