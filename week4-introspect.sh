#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
echo "==> ROOT: $ROOT"
echo

sep(){ echo; echo "------------------------------------------------------------"; echo; }

echo "==> 1) Repo hızlı ağaç (apps/api ilk 3 seviye)"
if [ -d "apps/api" ]; then
  (cd apps/api && find . -maxdepth 3 -type d | sed 's#^\./##' | sort | head -n 200)
else
  echo "apps/api yok. Monorepo yolu farklı olabilir."
fi
sep

echo "==> 2) Prisma schema dosyası nerede?"
SCHEMA_PATH=""
# En yaygın yerler
CANDIDATES=(
  "apps/api/prisma/schema.prisma"
  "apps/api/src/prisma/schema.prisma"
  "prisma/schema.prisma"
  "apps/api/schema.prisma"
)
for p in "${CANDIDATES[@]}"; do
  if [ -f "$p" ]; then SCHEMA_PATH="$p"; break; fi
done

# Bulamazsa find ile ara (ilk eşleşen)
if [ -z "$SCHEMA_PATH" ]; then
  FOUND="$(find . -maxdepth 5 -type f -name "schema.prisma" 2>/dev/null | head -n 1 || true)"
  if [ -n "${FOUND:-}" ]; then SCHEMA_PATH="$FOUND"; fi
fi

if [ -z "$SCHEMA_PATH" ]; then
  echo "schema.prisma bulunamadı."
else
  echo "FOUND: $SCHEMA_PATH"
fi
sep

echo "==> 3) Prisma: Role + User + Lead (+ Offer varsa) parçaları"
if [ -n "$SCHEMA_PATH" ]; then
  echo "--- schema.prisma (enum Role) ---"
  awk '
    BEGIN{p=0}
    /^enum[[:space:]]+Role[[:space:]]*\{/ {p=1; print; next}
    p==1 {print}
    p==1 && /^\}/ {p=0}
  ' "$SCHEMA_PATH" || true

  echo
  echo "--- schema.prisma (model User) ---"
  awk '
    BEGIN{p=0}
    /^model[[:space:]]+User[[:space:]]*\{/ {p=1; print; next}
    p==1 {print}
    p==1 && /^\}/ {p=0}
  ' "$SCHEMA_PATH" || true

  echo
  echo "--- schema.prisma (model Lead) ---"
  awk '
    BEGIN{p=0}
    /^model[[:space:]]+Lead[[:space:]]*\{/ {p=1; print; next}
    p==1 {print}
    p==1 && /^\}/ {p=0}
  ' "$SCHEMA_PATH" || true

  echo
  echo "--- schema.prisma (model Offer/LeadAssignment varsa) ---"
  for m in Offer LeadAssignment Assignment; do
    echo
    echo ">>> model $m"
    awk -v M="$m" '
      BEGIN{p=0}
      $0 ~ "^model[[:space:]]+"M"[[:space:]]*\\{" {p=1; print; next}
      p==1 {print}
      p==1 && /^\}/ {p=0}
    ' "$SCHEMA_PATH" || true
  done
fi
sep

echo "==> 4) Roles guard / decorator / auth guard isimleri (varsa)"
if [ -d "apps/api" ]; then
  rg -n --hidden --glob='!**/node_modules/**' --glob='!**/dist/**' \
    "Roles\\(|@Roles\\(|roles\\.guard|RolesGuard|JwtAuthGuard|AuthGuard\\('jwt'\\)" apps/api \
    || echo "roles/jwt guard pattern bulunamadı."
else
  rg -n --hidden --glob='!**/node_modules/**' --glob='!**/dist/**' \
    "Roles\\(|@Roles\\(|roles\\.guard|RolesGuard|JwtAuthGuard|AuthGuard\\('jwt'\\)" . \
    || echo "roles/jwt guard pattern bulunamadı."
fi
sep

echo "==> 5) Lead controller/service yolları (varsa)"
if [ -d "apps/api" ]; then
  rg -n --hidden --glob='!**/node_modules/**' --glob='!**/dist/**' \
    "class[[:space:]]+.*Lead|LeadsController|LeadsService|/leads" apps/api/src \
    || echo "Lead controller/service pattern bulunamadı."
else
  rg -n --hidden --glob='!**/node_modules/**' --glob='!**/dist/**' \
    "class[[:space:]]+.*Lead|LeadsController|LeadsService|/leads" . \
    || echo "Lead controller/service pattern bulunamadı."
fi
sep

echo "==> 6) Controller'larda route prefix taraması (NestJS @Controller('...'))"
if [ -d "apps/api/src" ]; then
  rg -n --hidden --glob='!**/node_modules/**' --glob='!**/dist/**' \
    "@Controller\\(" apps/api/src | head -n 200
else
  rg -n --hidden --glob='!**/node_modules/**' --glob='!**/dist/**' \
    "@Controller\\(" . | head -n 200
fi
sep

echo "==> DONE: Çıktıyı komple buraya yapıştır."
