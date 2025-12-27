#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ (sen yazmayacaksın)
cd ~/Desktop/teklif-platform

echo "==> ROOT: $(pwd)"

echo
echo "==> 1) Repo kontrol"
test -d .git || { echo "ERR: Bu dizin git repo değil"; exit 1; }

echo
echo "==> 2) Klasörleri hazırla"
mkdir -p scripts/sprint-next
mkdir -p .tmp

echo
echo "==> 3) Branch kontrol/oluştur (HEAD yoksa da çalışır)"
BR="sprint/deal-listing"

# HEAD yoksa bu komut patlayabilir; o yüzden fallback:
CURRENT="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo "__UNBORN__")"

if [ "$CURRENT" = "__UNBORN__" ]; then
  echo "   - UYARI: Repo'da HEAD yok (unborn). Branch ismi yine de ayarlanacak."
  # Bu durumda zaten bir branch üzerindesin; sadece istediğimiz branch'e geçmeye çalışalım:
  if git show-ref --verify --quiet "refs/heads/$BR"; then
    git checkout "$BR" || true
  else
    git checkout -b "$BR" || true
  fi
else
  if [ "$CURRENT" != "$BR" ]; then
    if git show-ref --verify --quiet "refs/heads/$BR"; then
      echo "   - Branch var: $BR -> checkout"
      git checkout "$BR"
    else
      echo "   - Branch yok: $BR -> create"
      git checkout -b "$BR"
    fi
  else
    echo "   - Zaten bu branch'tesin: $BR"
  fi
fi

echo
echo "==> 4) Hızlı durum"
# HEAD yokken de çalışır
git status -sb || true

echo
echo "==> 5) Git sağlık kontrolü"
git rev-parse --is-inside-work-tree >/dev/null && echo "OK: inside work tree"
git log -1 --oneline 2>/dev/null || echo "UYARI: Henüz commit yok (git log boş). Bu, geliştirmeyi engellemez."

echo
echo "✅ ADIM 1 TAMAM (fix)"
