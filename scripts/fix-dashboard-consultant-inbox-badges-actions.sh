#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

txt = orig

def must(pattern: str, label: str):
    if not re.search(pattern, txt, flags=re.S):
        raise SystemExit(f"❌ Pattern not found: {label}")

# 1) Normalize badge kind: linked > ready > claimed > open
# Replace existing getBadgeKind(...) function block (best-effort)
pat_kind = r"function\s+getBadgeKind\s*\(\s*[^)]*\)\s*\{[\s\S]*?\n\}"
must(pat_kind, "getBadgeKind() function")

new_kind = r"""function getBadgeKind(d: any): 'linked' | 'ready' | 'claimed' | 'open' {
  const status = String(d?.status || '').toUpperCase().trim();
  const hasListing = Boolean(d?.listingId || d?.linkedListingId);
  const consultantId = String(d?.consultantId || '').trim();

  if (hasListing) return 'linked';
  if (status === 'READY_FOR_MATCHING') return 'ready';
  if (consultantId) return 'claimed';
  return 'open';
}"""
txt = re.sub(pat_kind, new_kind, txt, count=1, flags=re.S)

# 2) Normalize badge label function if exists: getBadgeLabel(...)
# If not present, we won't fail (some versions inline labels). We patch if found.
pat_label = r"function\s+getBadgeLabel\s*\(\s*[^)]*\)\s*\{[\s\S]*?\n\}"
if re.search(pat_label, txt, flags=re.S):
    new_label = r"""function getBadgeLabel(d: any) {
  const k = getBadgeKind(d);
  if (k === 'linked') return 'Bağlandı';
  if (k === 'ready') return 'Hazır (Match)';
  if (k === 'claimed') return 'Üstlenildi';
  return 'Açık';
}"""
    txt = re.sub(pat_label, new_label, txt, count=1, flags=re.S)

# 3) Update the action button label "İlana Bağla" => "Eşleştir (Match)" and enable only when READY_FOR_MATCHING
# We patch the drawer button block where linkLabel/linkDisabled/linkTitle are computed.
must(r"const\s+linkDisabled\s*=", "linkDisabled block")
must(r"const\s+linkLabel\s*=", "linkLabel block")
must(r"const\s+linkTitle\s*=", "linkTitle block")

# Patch linkDisabled computation: only allow when kind === 'ready'
txt = re.sub(
    r"const\s+linkDisabled\s*=\s*[\s\S]*?;\n",
    "const linkDisabled =\n"
    "  Boolean(loadingList || busy || linkBusy) ||\n"
    "  !hasUserId ||\n"
    "  !selectedId ||\n"
    "  kind !== 'ready';\n",
    txt,
    count=1,
    flags=re.S
)

# Patch linkLabel: show "Eşleştir (Match)" with busy state
txt = re.sub(
    r"const\s+linkLabel\s*=\s*[\s\S]*?;\n",
    "const linkLabel =\n"
    "  kind === 'linked' ? 'Bağlandı' : linkBusy ? 'Eşleştiriliyor…' : 'Eşleştir (Match)';\n",
    txt,
    count=1,
    flags=re.S
)

# Patch linkTitle: align with READY_FOR_MATCHING gating
txt = re.sub(
    r"const\s+linkTitle\s*=\s*[\s\S]*?;\n",
    "const linkTitle =\n"
    "  !hasUserId\n"
    "    ? 'Önce x-user-id set et'\n"
    "    : !selectedId\n"
    "    ? 'Önce bir kayıt seç'\n"
    "    : kind !== 'ready'\n"
    "    ? 'Bu talep match için hazır değil (READY_FOR_MATCHING olmalı)'\n"
    "    : linkBusy\n"
    "    ? 'Eşleştirme işlemi devam ediyor'\n"
    "    : 'Bu talebi eşleştir (match)';\n",
    txt,
    count=1,
    flags=re.S
)

# 4) Replace the hardcoded button text usages in JSX, if any remain
txt = txt.replace("İlana Bağla", "Eşleştir (Match)")

if txt == orig:
    raise SystemExit("❌ No changes applied (unexpected).")

bak = p.with_suffix(p.suffix + ".badges-actions.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Patched Consultant Inbox badges + match button gating (READY_FOR_MATCHING only)")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> ESLint"
pnpm -C apps/dashboard -s eslint "app/consultant/inbox/page.tsx"
echo "✅ Done."
