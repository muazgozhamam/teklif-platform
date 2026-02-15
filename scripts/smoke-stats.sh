#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
CONSULTANT_EMAIL="${CONSULTANT_EMAIL:-consultant1@test.com}"
CONSULTANT_PASSWORD="${CONSULTANT_PASSWORD:-pass123}"
BROKER_EMAIL="${BROKER_EMAIL:-broker.stats@local.dev}"
BROKER_PASSWORD="${BROKER_PASSWORD:-pass123}"
HUNTER_EMAIL="${HUNTER_EMAIL:-hunter.stats@local.dev}"
HUNTER_PASSWORD="${HUNTER_PASSWORD:-pass123}"

need_bin() {
  command -v "$1" >/dev/null 2>&1 || { echo "HATA: '$1' bulunamadı"; exit 2; }
}

need_bin jq

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

admin_call() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  if [ -n "$body" ]; then
    curl -fsS -X "$method" "$BASE_URL$path" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "$body"
  else
    curl -fsS -X "$method" "$BASE_URL$path" -H "Authorization: Bearer $ADMIN_TOKEN"
  fi
}

find_user_id_by_email() {
  local email="$1"
  admin_call GET "/admin/users?take=200&q=$(printf '%s' "$email" | sed 's/@/%40/g')" \
    | jq -r --arg email "$email" '.[] | select(.email == $email) | .id' \
    | head -n1
}

ensure_role_user() {
  local email="$1"
  local password="$2"
  local role="$3"
  local tok

  tok="$(login_token "$email" "$password" || true)"
  if [ -n "$tok" ]; then
    echo "$tok"
    return 0
  fi

  local user_id
  user_id="$(find_user_id_by_email "$email")"
  if [ -z "$user_id" ]; then
    user_id="$(admin_call POST "/admin/users" "{\"email\":\"$email\",\"password\":\"$password\",\"role\":\"$role\"}" | jq -r '.id // empty')"
  fi
  [ -n "$user_id" ] || { echo "HATA: kullanıcı oluşturulamadı/bulunamadı ($email)"; exit 1; }

  admin_call PATCH "/admin/users/$user_id" "{\"role\":\"$role\",\"isActive\":true}" >/dev/null
  admin_call POST "/admin/users/$user_id/set-password" "{\"password\":\"$password\"}" >/dev/null

  tok="$(login_token "$email" "$password" || true)"
  [ -n "$tok" ] || { echo "HATA: role user login başarısız ($email)"; exit 1; }
  echo "$tok"
}

assert_keys() {
  local json="$1"
  shift
  for key in "$@"; do
    echo "$json" | jq -e --arg k "$key" '.[$k] | numbers' >/dev/null || {
      echo "HATA: beklenen numeric key yok: $key"
      echo "$json"
      exit 1
    }
  done
}

check_stats() {
  local role="$1"
  local token="$2"
  local json
  json="$(curl -fsS "$BASE_URL/stats/me" -H "Authorization: Bearer $token")"
  echo "$json" | jq -e --arg role "$role" '.role == $role' >/dev/null || {
    echo "HATA: role beklenen değil ($role)"
    echo "$json"
    exit 1
  }

  case "$role" in
    ADMIN)
      assert_keys "$json" usersTotal leadsTotal dealsTotal listingsTotal
      ;;
    CONSULTANT)
      assert_keys "$json" dealsMineOpen dealsReadyForListing listingsDraft listingsPublished listingsSold
      ;;
    BROKER)
      assert_keys "$json" leadsPending leadsApproved dealsCreated
      ;;
    HUNTER)
      assert_keys "$json" leadsTotal leadsNew leadsReview leadsApproved leadsRejected
      ;;
    *)
      echo "HATA: bilinmeyen role doğrulaması: $role"
      exit 1
      ;;
  esac
  echo "OK /stats/me role=$role"
}

echo "==> BASE_URL=$BASE_URL"
echo "==> 1) Admin login"
ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "HATA: admin login başarısız"; exit 1; }
echo "OK admin=$ADMIN_EMAIL"

echo "==> 2) Consultant login"
CONSULTANT_TOKEN="$(ensure_role_user "$CONSULTANT_EMAIL" "$CONSULTANT_PASSWORD" "CONSULTANT")"
[ -n "$CONSULTANT_TOKEN" ] || { echo "HATA: consultant login başarısız"; exit 1; }
echo "OK consultant=$CONSULTANT_EMAIL"

echo "==> 3) Ensure broker/hunter users"
BROKER_TOKEN="$(ensure_role_user "$BROKER_EMAIL" "$BROKER_PASSWORD" "BROKER")"
HUNTER_TOKEN="$(ensure_role_user "$HUNTER_EMAIL" "$HUNTER_PASSWORD" "HUNTER")"
echo "OK broker=$BROKER_EMAIL"
echo "OK hunter=$HUNTER_EMAIL"

echo "==> 4) /stats/me validations"
check_stats "ADMIN" "$ADMIN_TOKEN"
check_stats "CONSULTANT" "$CONSULTANT_TOKEN"
check_stats "BROKER" "$BROKER_TOKEN"
check_stats "HUNTER" "$HUNTER_TOKEN"

echo
echo "✅ SMOKE OK (stats)"
