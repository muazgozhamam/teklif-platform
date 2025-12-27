#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

echo "==> ROOT: $(pwd)"

echo
echo "==> 1) .gitignore oluştur/güncelle"
# Mevcut .gitignore varsa üzerine ek yapacağız (overwrite değil).
touch .gitignore

python3 - <<'PY'
from pathlib import Path

p = Path(".gitignore")
txt = p.read_text(encoding="utf-8").splitlines()

wanted = [
  "# --- generated / caches ---",
  ".tmp/",
  ".turbo/",
  "node_modules/",
  "dist/",
  "*.log",
  ".DS_Store",
  "",
  "# --- local env ---",
  ".env",
  ".env.*",
  "",
  "# --- prisma ---",
  "apps/api/prisma/dev.db",
  "apps/api/prisma/dev.db-journal",
]

# Append only missing lines (preserve existing)
existing = set(txt)
out = txt[:]
for line in wanted:
  if line not in existing:
    out.append(line)

p.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
print("✅ .gitignore updated")
PY

echo
echo "==> 2) tmp/log dosyalarını temizle (güvenli)"
rm -rf .tmp .turbo || true
rm -f .tmp-*.log .tmp-*.out || true

echo
echo "==> 3) Git status (temizliği doğrula)"
git status -sb || true

echo
echo "==> 4) İlk commit (repo hiç commit yoksa)"
# HEAD yoksa commit gerekir; varsa bu adım sadece stage+commit yapar.
git add -A

# Eğer stage'e hiçbir şey eklenmediyse commit atma
if git diff --cached --quiet; then
  echo "UYARI: Commit edilecek değişiklik yok."
else
  git commit -m "chore: initialize repo and ignore generated artifacts"
  echo "✅ First commit created"
fi

echo
echo "==> 5) Son durum"
git status -sb || true
git log -1 --oneline || true

echo
echo "✅ ADIM 2 TAMAM"
