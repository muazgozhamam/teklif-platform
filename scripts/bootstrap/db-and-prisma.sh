#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"
COMPOSE_FILE="$ROOT_DIR/docker-compose.db.yml"

DB_NAME="${DB_NAME:-emlak}"
DB_USER="${DB_USER:-postgres}"
DB_PASS="${DB_PASS:-postgres}"
DB_PORT="${DB_PORT:-5432}"
API_PORT="${API_PORT:-3001}"

say() { printf "\n==> %s\n" "$*"; }

need_api_dir() {
  if [ ! -d "$API_DIR" ]; then
    echo "HATA: apps/api bulunamadı. Önce API reset scriptini çalıştır."
    exit 1
  fi
}

write_env() {
  say "apps/api/.env yazılıyor"
  cat > "$API_DIR/.env" <<ENV
DATABASE_URL="postgresql://localhost:${DB_PORT}/${DB_NAME}"
PORT=${API_PORT}
NODE_ENV=development
ENV
}

prisma7_fix_and_push() {
  say "Prisma 7 uyumluluk: schema url kaldır + prisma.config.ts yaz"
  cd "$API_DIR"

  # schema.prisma -> url satırını kaldır
  if grep -q "url *= *env(\"DATABASE_URL\"\)" prisma/schema.prisma 2>/dev/null; then
    perl -0777 -i -pe 's/\n\s*url\s*=\s*env\("DATABASE_URL"\)\s*\n/\n/gs' prisma/schema.prisma
  fi

  # prisma.config.ts -> migrate/db push için url burada
  cat > prisma.config.ts <<'TS'
import { defineConfig } from "prisma/config";
export default defineConfig({
  datasource: {
    url: process.env.DATABASE_URL!,
  },
});
TS

  say "Prisma generate + db push"
  npx prisma generate
  npx prisma db push
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

start_db_with_docker() {
  say "Docker bulundu. Postgres container ile DB ayağa kaldırılıyor"

  cat > "$COMPOSE_FILE" <<YAML
services:
  db:
    image: postgres:16
    container_name: emlak_db
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_DB: ${DB_NAME}
    ports:
      - "${DB_PORT}:5432"
YAML

  docker compose -f "$COMPOSE_FILE" up -d
  say "Docker DB hazır: localhost:${DB_PORT}/${DB_NAME}"
}

start_db_with_brew() {
  say "Docker yok. Homebrew + Postgres ile lokal DB ayağa kaldırılacak"

  if ! have_cmd brew; then
    echo "HATA: Homebrew (brew) bulunamadı."
    echo "Çözüm: Homebrew kur ve tekrar çalıştır:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
  fi

  # Postgres 16 kurulu mu?
  if ! brew list postgresql@16 >/dev/null 2>&1; then
    say "postgresql@16 kuruluyor"
    brew install postgresql@16
  else
    say "postgresql@16 zaten kurulu"
  fi

  say "Postgres servisi başlatılıyor"
  brew services start postgresql@16 >/dev/null 2>&1 || true

  # DB var mı?
  if have_cmd psql; then
    if psql -lqt 2>/dev/null | cut -d \| -f 1 | tr -d ' ' | grep -qx "$DB_NAME"; then
      say "DB zaten var: ${DB_NAME}"
    else
      say "DB oluşturuluyor: ${DB_NAME}"
      createdb "$DB_NAME"
    fi
  else
    echo "HATA: psql bulunamadı. Kurulum bozuk görünüyor."
    exit 1
  fi

  say "Lokal DB hazır: localhost:${DB_PORT}/${DB_NAME}"
}

main() {
  need_api_dir

  if have_cmd docker; then
    start_db_with_docker
  else
    start_db_with_brew
  fi

  write_env
  prisma7_fix_and_push

  say "Bitti. API çalıştır:"
  echo "  cd apps/api && pnpm start:dev"
  echo "  curl http://localhost:${API_PORT}/health"
}

main "$@"

