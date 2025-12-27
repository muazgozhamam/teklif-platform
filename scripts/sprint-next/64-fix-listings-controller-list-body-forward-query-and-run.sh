#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="$ROOT/apps/api/src/listings/listings.controller.ts"
SMOKE="$ROOT/scripts/sprint-next/36-smoke-listings-pagination.sh"
LOG="$ROOT/.tmp/64.pagination-smoke.log"

mkdir -p "$ROOT/.tmp"

echo "==> ROOT=$ROOT"
echo "==> Target: $TARGET"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.controller.ts")
txt = p.read_text(encoding="utf-8")

# Locate the list method with current signature
m = re.search(r"\blist\s*\(\s*@Query\(\)\s*query\s*:\s*any\s*\)\s*{", txt)
if not m:
    raise SystemExit("❌ Could not find: list(@Query() query: any) {  in listings.controller.ts")

start = m.start()
brace_open = txt.find("{", m.end()-1)
if brace_open == -1:
    raise SystemExit("❌ Could not find opening brace for list(...)")

# Find matching closing brace for this method body
i = brace_open
depth = 0
in_str = None
escape = False
while i < len(txt):
    ch = txt[i]
    if in_str:
        if escape:
            escape = False
        elif ch == "\\":
            escape = True
        elif ch == in_str:
            in_str = None
    else:
        if ch in ("'", '"', "`"):
            in_str = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                brace_close = i
                break
    i += 1
else:
    raise SystemExit("❌ Could not find closing brace for list(...) body")

method_block = txt[start:brace_close+1]

# Try to detect the injected service property used previously: return this.<prop>.list(...)
svc = None
m_svc = re.search(r"return\s+this\.(\w+)\.list\s*\(", method_block)
if m_svc:
    svc = m_svc.group(1)
else:
    # fallback: detect constructor injection "private readonly <name>: ListingsService"
    m_ctor = re.search(r"constructor\s*\(\s*[^)]*private\s+readonly\s+(\w+)\s*:\s*ListingsService", txt, re.DOTALL)
    if m_ctor:
        svc = m_ctor.group(1)

if not svc:
    # last fallback: common names
    svc = "listings"

# Determine indentation (use two spaces after newline at method body level)
# We'll reuse indentation from existing file around the method.
line_start = txt.rfind("\n", 0, start) + 1
indent = re.match(r"[ \t]*", txt[line_start:start]).group(0)
body_indent = indent + "  "

new_method = (
    f"{indent}list(@Query() query: any) {{\n"
    f"{body_indent}return this.{svc}.list(query as any);\n"
    f"{indent}}}"
)

txt2 = txt[:start] + new_method + txt[brace_close+1:]

# Sanity: list signature must exist and must not reference shorthand props like 'city,' in controller mapping block
if "list(@Query() query: any)" not in txt2:
    raise SystemExit("❌ Post-fix sanity failed: signature missing")

p.write_text(txt2, encoding="utf-8")
print(f"✅ Patched list() body to forward query: return this.{svc}.list(query as any);")
PY

echo
echo "==> Build (dist clean + build)"
bash "$ROOT/scripts/sprint-next/11-fix-api-dist-enotempty-build.sh"

echo
echo "==> Start API dev (3001)"
bash "$ROOT/scripts/sprint-next/05-start-api-dev-3001.sh"

echo
echo "==> Run pagination smoke (36) -> $LOG"
BASE_URL="${BASE_URL:-http://localhost:3001}" bash "$SMOKE" | tee "$LOG"

echo
echo "✅ ALL DONE. Log: $LOG"
