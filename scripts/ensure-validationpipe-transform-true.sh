#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

if [ ! -f "$ROOT/pnpm-workspace.yaml" ]; then
  echo "❌ Repo root bulunamadı (pnpm-workspace.yaml yok). ROOT=$ROOT"
  exit 1
fi

MAIN="$ROOT/apps/api/src/main.ts"
if [ ! -f "$MAIN" ]; then
  echo "❌ Missing: $MAIN"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/main.ts")
txt = p.read_text(encoding="utf-8")
orig = txt

# Find the first occurrence of app.useGlobalPipes( ... new ValidationPipe( ... ) ... )
# We'll patch only within that call to avoid unintended replacements.
m = re.search(r"app\.useGlobalPipes\(\s*new\s+ValidationPipe\s*\(([\s\S]*?)\)\s*\)\s*;", txt)
if not m:
    print("⚠️  Could not find pattern: app.useGlobalPipes(new ValidationPipe(...));")
    print("    No changes applied.")
    raise SystemExit(0)

inner = m.group(1).strip()

# Case A: no args -> new ValidationPipe()
if inner == "":
    repl = "app.useGlobalPipes(new ValidationPipe({ transform: true }));"
    txt = txt[:m.start()] + repl + txt[m.end():]

# Case B: object literal args -> new ValidationPipe({ ... })
elif inner.startswith("{") and inner.endswith("}"):
    # if transform already present, do nothing
    if re.search(r"\btransform\s*:", inner):
        print("ℹ️  ValidationPipe already has transform option; no changes.")
        raise SystemExit(0)
    # inject transform: true right after '{'
    new_inner = re.sub(r"^\{\s*", "{ transform: true, ", inner, count=1)
    repl = f"app.useGlobalPipes(new ValidationPipe({new_inner}));"
    txt = txt[:m.start()] + repl + txt[m.end():]

# Case C: something else (variable/options) -> don't guess
else:
    print("⚠️  ValidationPipe is not configured with a direct object literal or empty args.")
    print("    Found args:", inner[:120].replace("\n"," ") + ("..." if len(inner) > 120 else ""))
    print("    No changes applied (to avoid breaking boot).")
    raise SystemExit(0)

bak = p.with_suffix(p.suffix + ".transformtrue.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Ensured ValidationPipe has transform:true")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Build API (typecheck)"
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Done."
