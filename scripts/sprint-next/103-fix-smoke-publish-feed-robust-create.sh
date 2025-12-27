#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="$ROOT/scripts/sprint-next/101-smoke-publish-feed.sh"

echo "==> ROOT=$ROOT"
echo "==> Patching: $TARGET"
[ -f "$TARGET" ] || { echo "❌ Missing: $TARGET"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("scripts/sprint-next/101-smoke-publish-feed.sh")
txt = p.read_text(encoding="utf-8")

# Replace http_post_json to return "body\n__HTTP_STATUS:XXX"
pat = r"""http_post_json\(\)\s*\{\n.*?\n\}"""
m = re.search(pat, txt, flags=re.S)
if not m:
    raise SystemExit("❌ Could not find http_post_json() function to patch in 101-smoke-publish-feed.sh")

new_fn = r"""http_post_json() {
  local url="$1" json="$2"
  curl -sS --connect-timeout 5 --max-time 20 \
    -H "Content-Type: application/json" \
    -X POST "$url" -d "$json" \
    -w '\n__HTTP_STATUS:%{http_code}\n'
}"""

txt2 = txt[:m.start()] + new_fn + txt[m.end():]

# Patch the create block to parse status+body robustly and print diagnostics on failure
# We expect these lines exist:
# resp="$(http_post_json ...)"
# id="$(printf "%s" "$resp" | json_get_id)"
# We'll replace that segment.
create_block_pat = r"""echo "==> 1\) Create listing \(should be DRAFT\)"\njson="\$\(\s*python3.*?\n\)"\nresp="\$\(\s*http_post_json.*?\n\)"\nid="\$\(\s*printf.*?json_get_id\)"\n\[ -n "\$id" \ ] \|\| \{.*?\n\}\n"""
m2 = re.search(create_block_pat, txt2, flags=re.S)
if not m2:
    # fallback: do a simpler targeted replace for known lines
    txt2 = txt2.replace(
        'resp="$(http_post_json "$BASE_URL/listings" "$json")"\n'
        'id="$(printf "%s" "$resp" | json_get_id)"\n'
        '[ -n "$id" ] || { echo "❌ Could not parse id"; echo "$resp"; exit 1; }\n',
        'raw="$(http_post_json "$BASE_URL/listings" "$json")"\n'
        'body="${raw%$\'\\n\'__HTTP_STATUS:*}"\n'
        'status="${raw##*__HTTP_STATUS:}"\n'
        'status="$(printf "%s" "$status" | tr -d \'\\r\\n \' )"\n'
        'if [ "$status" != "201" ] && [ "$status" != "200" ]; then\n'
        '  echo "❌ Create listing failed: http=$status"\n'
        '  echo "---- BODY ----"\n'
        '  printf "%s\\n" "$body"\n'
        '  exit 1\n'
        'fi\n'
        'id="$(printf "%s" "$body" | json_get_id || true)"\n'
        'if [ -z "$id" ]; then\n'
        '  echo "❌ Could not parse id from create response (http=$status)"\n'
        '  echo "---- BODY ----"\n'
        '  printf "%s\\n" "$body"\n'
        '  exit 1\n'
        'fi\n'
    )
else:
    raise SystemExit("❌ Unexpected: create block matched complex pattern. Refusing risky rewrite.")

# Make json_get_id print nothing but not crash the pipe on empty/non-json (it currently may crash python)
# We'll replace json_get_id body to guard.
jg_pat = r"""json_get_id\(\)\s*\{\npython3\s+-\s+<<'PY'\n.*?\nPY\n\}"""
m3 = re.search(jg_pat, txt2, flags=re.S)
if not m3:
    raise SystemExit("❌ Could not find json_get_id() to patch.")
new_jg = r"""json_get_id() {
python3 - <<'PY'
import json,sys
s=sys.stdin.read().strip()
if not s:
  sys.exit(0)
try:
  obj=json.loads(s)
except Exception:
  sys.exit(0)
v=obj.get("id")
if isinstance(v,str) and v:
  print(v)
PY
}"""
txt2 = txt2[:m3.start()] + new_jg + txt2[m3.end():]

p.write_text(txt2, encoding="utf-8")
print("✅ Patched 101-smoke-publish-feed.sh: robust create (status+body) + safe json_get_id.")
PY

chmod +x "$TARGET"
echo "✅ Done."
echo
echo "==> Running golden again"
bash "$ROOT/scripts/sprint-next/102-golden-publish-feed.sh" | tee "$ROOT/.tmp/103.golden.rerun.log"

echo
echo "✅ Finished. Log: $ROOT/.tmp/103.golden.rerun.log"
