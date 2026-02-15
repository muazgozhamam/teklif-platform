#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FILE="$ROOT/apps/dashboard/app/consultant/inbox/page.tsx"

[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# Safety: if already restored, abort
if re.search(r"async function load\(", orig):
    raise SystemExit("ℹ️ load() already exists; not applying restore patch.")

# 1) Ensure we have getUserIdFromStorage helper (it exists in your file, but keep safe)
if "function getUserIdFromStorage" not in orig:
    raise SystemExit("❌ getUserIdFromStorage() not found (unexpected).")

# 2) Anchor: after `const list = tab === 'pending' ? pending : mine;`
anchor = re.search(r"const\s+list\s*=\s*tab\s*===\s*'pending'\s*\?\s*pending\s*:\s*mine\s*;\s*\n", orig)
if not anchor:
    raise SystemExit("❌ Anchor not found: `const list = tab === 'pending' ? pending : mine;`")

insert = r"""

  // Restore userId from localStorage on mount (needed for Mine tab + actions)
  useEffect(() => {
    setUserId(getUserIdFromStorage());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function load(which: 'pending' | 'mine' = tab) {
    const tTake = Math.min(50, Math.max(1, Number(take || 20)));
    const skip = which === 'pending' ? pendingSkip : mineSkip;

    setErr('');
    setLoadingList(true);

    try {
      if (which === 'pending') {
        const r = await fetch(`${API_BASE}/deals/inbox/pending?take=${tTake}&skip=${skip}`, { cache: 'no-store' });
        const { json, raw } = await readJsonOrText(r);
        if (!r.ok) throw new Error(`pending ${r.status}: ${(json && (json.message || json.error)) || raw || 'error'}`);

        const arr = (json || []) as Deal[];
        setPending(arr);
        setHasMorePending(Array.isArray(arr) && arr.length >= tTake);
        setLastAction(`loaded pending=${arr.length} take=${tTake} skip=${skip}`);
        return;
      }

      // mine
      if (!hasUserId) {
        setMine([]);
        setHasMoreMine(false);
        setLastAction(`mine skipped (missing userId)`);
        return;
      }

      const r2 = await fetch(`${API_BASE}/deals/inbox/mine?take=${tTake}&skip=${skip}`, {
        cache: 'no-store',
        headers: { 'x-user-id': userId },
      });
      const { json: j2, raw: raw2 } = await readJsonOrText(r2);
      if (!r2.ok) throw new Error(`mine ${r2.status}: ${(j2 && (j2.message || j2.error)) || raw2 || 'error'}`);

      const arr2 = (j2 || []) as Deal[];
      setMine(arr2);
      setHasMoreMine(Array.isArray(arr2) && arr2.length >= tTake);
      setLastAction(`loaded mine=${arr2.length} take=${tTake} skip=${skip}`);
    } catch (e: unknown) {
      setErr(getErrMsg(e, 'Load failed'));
    } finally {
      setLoadingList(false);
    }
  }

  // Auto-load on tab/userId/paging changes
  useEffect(() => {
    void load(tab);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, userId, take, pendingSkip, mineSkip]);

"""

new = orig[:anchor.end()] + insert + orig[anchor.end():]

bak = p.with_suffix(p.suffix + ".restore-load.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Restored load()+fetch for pending/mine + userId bootstrap")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> ESLint (info only)"
pnpm -C apps/dashboard exec eslint "app/consultant/inbox/page.tsx" 2>&1 | sed -n '1,120p' || true

echo
echo "==> Next build"
pnpm -C apps/dashboard -s build
echo "✅ Done."
