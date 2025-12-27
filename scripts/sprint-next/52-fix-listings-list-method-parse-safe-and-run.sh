#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="$ROOT/apps/api/src/listings/listings.service.ts"
SMOKE="$ROOT/scripts/sprint-next/36-smoke-listings-pagination.sh"
LOG_DIR="$ROOT/.tmp"
LOG="$LOG_DIR/52.pagination.log"

mkdir -p "$LOG_DIR"

echo "==> ROOT=$ROOT"
echo "==> Target: $FILE"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

echo
echo "==> 1) Fix async list(...) method (parse-safe) + remove trailing broken leftovers"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8")

# ---- helpers: parse parentheses and braces safely ----
def find_matching_paren(s: str, open_pos: int) -> int:
    depth = 0
    in_str = None
    esc = False
    for i in range(open_pos, len(s)):
        ch = s[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == in_str:
                in_str = None
            continue
        if ch in ("'", '"', "`"):
            in_str = ch
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1

def find_matching_brace(s: str, open_pos: int) -> int:
    depth = 0
    in_str = None
    esc = False
    for i in range(open_pos, len(s)):
        ch = s[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == in_str:
                in_str = None
            continue
        if ch in ("'", '"', "`"):
            in_str = ch
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
    return -1

# 1) Find "async list(" start
m = re.search(r"\basync\s+list\s*\(", txt)
if not m:
    raise SystemExit("❌ Could not find 'async list('")

method_start = m.start()

# 2) Find the '(' of parameter list
paren_open = txt.find("(", m.end()-1)
if paren_open < 0:
    raise SystemExit("❌ Could not find '(' after async list")

paren_close = find_matching_paren(txt, paren_open)
if paren_close < 0:
    raise SystemExit("❌ Could not match ')' for list(...) params")

# 3) Find method body '{' after the params close
body_open = txt.find("{", paren_close)
if body_open < 0:
    raise SystemExit("❌ Could not find '{' for list() body")

body_close = find_matching_brace(txt, body_open)
if body_close < 0:
    raise SystemExit("❌ Could not match '}' for list() body")

# Determine indentation at method_start line
line_start = txt.rfind("\n", 0, method_start) + 1
indent = ""
i = line_start
while i < len(txt) and txt[i] in (" ", "\t"):
    indent += txt[i]
    i += 1

# Build a clean method with a SAFE signature (no default object literal in params)
new_method = f"""{indent}async list(filters: any = {{}}) {{
{indent}  const where: any = {{}};

{indent}  // status-based publishing:
{indent}  // default: only PUBLISHED
{indent}  // published=false: include drafts too
{indent}  const publishedRaw: any = (filters as any)?.published;
{indent}  const publishedFalse =
{indent}    publishedRaw === false ||
{indent}    publishedRaw === 'false' ||
{indent}    publishedRaw === 0 ||
{indent}    publishedRaw === '0';

{indent}  if ((filters as any)?.status) {{
{indent}    where.status = (filters as any).status;
{indent}  }} else if (!publishedFalse) {{
{indent}    where.status = 'PUBLISHED';
{indent}  }}

{indent}  if ((filters as any)?.city) where.city = (filters as any).city;
{indent}  if ((filters as any)?.district) where.district = (filters as any).district;
{indent}  if ((filters as any)?.type) where.type = (filters as any).type;
{indent}  if ((filters as any)?.rooms) where.rooms = (filters as any).rooms;
{indent}  if ((filters as any)?.consultantId) where.consultantId = (filters as any).consultantId;

{indent}  // pagination: page/pageSize OR skip/take
{indent}  const pageSizeRaw = Number((filters as any)?.pageSize ?? (filters as any)?.take ?? 20);
{indent}  const pageRaw = Number((filters as any)?.page ?? 1);
{indent}  const pageSize = Number.isFinite(pageSizeRaw) && pageSizeRaw > 0 ? min(pageSizeRaw, 100) : 20;
{indent}  const page = Number.isFinite(pageRaw) && pageRaw > 0 ? pageRaw : 1;

{indent}  let take = pageSize;
{indent}  let skip = (page - 1) * pageSize;

{indent}  const takeRaw = Number((filters as any)?.take);
{indent}  const skipRaw = Number((filters as any)?.skip);
{indent}  if (Number.isFinite(takeRaw) && takeRaw > 0) take = min(takeRaw, 100);
{indent}  if (Number.isFinite(skipRaw) && skipRaw >= 0) skip = skipRaw;

{indent}  // ordering
{indent}  const sortByRaw = String((filters as any)?.sortBy ?? (filters as any)?.orderBy ?? 'createdAt');
{indent}  const dirRaw = String((filters as any)?.sortDir ?? (filters as any)?.direction ?? 'desc').toLowerCase();
{indent}  const direction = dirRaw === 'asc' ? 'asc' : 'desc';
{indent}  const allowed = new Set(['createdAt', 'updatedAt', 'price', 'title']);
{indent}  const sortBy = allowed.has(sortByRaw) ? sortByRaw : 'createdAt';

{indent}  const orderBy: any = {{}};
{indent}  orderBy[sortBy] = direction;

{indent}  const [items, total] = await Promise.all([
{indent}    this.prisma.listing.findMany({{ where, orderBy, skip, take }}),
{indent}    this.prisma.listing.count({{ where }}),
{indent}  ]);

{indent}  return {{ items, total, page, pageSize }};
{indent}}}
"""

# Replace the entire method from "async list(" start through body_close (inclusive)
txt2 = txt[:method_start] + new_method + txt[body_close+1:]

# Fix: Python injected min(...) calls; replace with Math.min in TS
txt2 = txt2.replace("min(", "Math.min(")

# 4) Remove leftover broken junk *immediately following* list() if any:
# Find end of new_method within txt2, then if next non-whitespace token is ") {", delete until next method signature.
new_end = method_start + len(new_method)
after = txt2[new_end:]

# locate first non-space/comment char position after method
k = 0
while k < len(after) and after[k] in " \t\r\n":
    k += 1

# If stray begins with ") {", it's leftover from previous broken replace
if after[k:k+2] == ") " or after[k:k+1] == ")":
    # find next method signature at same indentation (rough heuristic)
    # match "\n<indent>(async )?name("
    pat = re.compile(r"\n" + re.escape(indent) + r"(?:async\s+)?[A-Za-z_]\w*\s*\(", re.M)
    mm = pat.search(after)
    if mm:
        # remove from k (relative) to mm.start()
        after2 = after[:k] + after[mm.start():]
        txt2 = txt2[:new_end] + after2

# 5) Ensure only one async list remains
if len(re.findall(r"\basync\s+list\s*\(", txt2)) != 1:
    raise SystemExit("❌ Post-fix sanity failed: expected exactly one 'async list('")

p.write_text(txt2, encoding="utf-8")
print("✅ Patched: list() replaced parse-safely and cleaned trailing leftovers.")
PY

echo
echo "==> 2) dist clean + build (standard)"
bash "$ROOT/scripts/sprint-next/11-fix-api-dist-enotempty-build.sh"

echo
echo "==> 3) Start API dev (3001)"
bash "$ROOT/scripts/sprint-next/05-start-api-dev-3001.sh"

echo
echo "==> 4) Run pagination smoke"
bash "$SMOKE" | tee "$LOG"

echo
echo "✅ ALL DONE. Log: $LOG"
