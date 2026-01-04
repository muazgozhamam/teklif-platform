#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/apps/dashboard/app/consultant/inbox/page.tsx"

echo "==> Smart drawer claim button"
echo "ROOT=$ROOT"
echo "FILE=$FILE"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
txt = p.read_text(encoding="utf-8")
bak = p.with_suffix(p.suffix + ".drawerbtn72.bak")
bak.write_text(txt, encoding="utf-8")

pattern = re.compile(r"""
\{tab\s*===\s*'pending'\s*\?\s*\(\s*
\s*<button
[\s\S]*?
</button>\s*
\)\s*:\s*null\s*\}
""", re.VERBOSE)

m = pattern.search(txt)
if not m:
    raise SystemExit("❌ Drawer claim button block not found. File may have changed.")

replacement = r"""
{(() => {
  const kind = getBadgeKind(selected);
  const claimedBy = (selected as any)?.consultantId || '';
  const isMine = hasUserId && claimedBy && claimedBy === userId;

  // Only show the action area when we're in pending tab.
  if (tab !== 'pending') return null;

  // Decide label + disabled state
  let label = 'Üstlen';
  let disabled = loading || !hasUserId;

  if (!hasUserId) {
    label = 'Üstlenmek için x-user-id gerekli';
    disabled = true;
  } else if (kind === 'linked') {
    label = 'Eşleşti (Linked)';
    disabled = true;
  } else if (kind === 'claimed') {
    label = isMine ? 'Bende (Claimed)' : 'Başkasında (Claimed)';
    disabled = true;
  } else {
    // open
    label = 'Üstlen';
    disabled = loading;
  }

  return (
    <button
      disabled={disabled}
      onClick={async () => {
        if (disabled) return;
        if (!selectedId) return;
        await claim(selectedId);
        // claim() already loads + sets tab mine; keep drawer open but refresh selection
        try {
          const d = await fetchDealById(selectedId);
          setSelected(d);
        } catch {}
      }}
      style={{
        padding: '8px 10px',
        borderRadius: 10,
        border: disabled ? '1px solid #e5e7eb' : '1px solid #111827',
        background: disabled ? '#f8fafc' : '#111827',
        color: disabled ? '#64748b' : '#fff',
        cursor: disabled ? 'not-allowed' : 'pointer',
      }}
      title={
        !hasUserId
          ? 'Önce x-user-id set et'
          : kind === 'linked'
          ? 'Bu talep bir ilana bağlanmış'
          : kind === 'claimed'
          ? (isMine ? 'Zaten sende' : 'Başka danışmanda')
          : 'Üstlen'
      }
    >
      {label}
    </button>
  );
})()}
"""

txt2 = txt[:m.start()] + replacement + txt[m.end():]
p.write_text(txt2, encoding="utf-8")

print("✅ Drawer claim button smartened")
print("Backup:", bak)
PY

echo "✅ DONE"
