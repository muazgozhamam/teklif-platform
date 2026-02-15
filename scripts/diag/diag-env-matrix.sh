#!/usr/bin/env bash
set -euo pipefail

ENV_TARGET="${ENV_TARGET:-local}"  # local|staging|production
ENV_FILE="${ENV_FILE:-}"

if [ -n "$ENV_FILE" ]; then
  if [ ! -f "$ENV_FILE" ]; then
    echo "❌ ENV_FILE not found: $ENV_FILE"
    exit 1
  fi
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

case "$ENV_TARGET" in
  local|staging|production) ;;
  *)
    echo "❌ ENV_TARGET must be one of: local|staging|production"
    exit 1
    ;;
esac

fail=0
warn=0

ok() { echo "✅ $1"; }
ng() { echo "❌ $1"; fail=1; }
wa() { echo "⚠️  $1"; warn=1; }

require_non_empty() {
  local name="$1"
  local value="${!name:-}"
  if [ -z "${value// }" ]; then
    ng "$name is required"
  else
    ok "$name is set"
  fi
}

forbid_enabled() {
  local name="$1"
  local value
  value="$(echo "${!name:-}" | tr '[:upper:]' '[:lower:]' | xargs)"
  if [ "$value" = "1" ] || [ "$value" = "true" ] || [ "$value" = "yes" ] || [ "$value" = "on" ]; then
    ng "$name must be disabled"
  else
    ok "$name is not enabled"
  fi
}

require_not_default_like() {
  local name="$1"
  local value="${!name:-}"
  if [ -z "${value// }" ]; then
    ng "$name is required"
    return
  fi
  if [ "$value" = "dev-secret" ] || [ "$value" = "change-me" ] || [ "$value" = "secret" ]; then
    ng "$name uses insecure default-like value"
  else
    ok "$name is non-default"
  fi
}

echo "==> diag-env-matrix"
echo "ENV_TARGET=$ENV_TARGET"
if [ -n "$ENV_FILE" ]; then
  echo "ENV_FILE=$ENV_FILE"
fi

# Always required
require_non_empty DATABASE_URL

if [ "$ENV_TARGET" = "local" ]; then
  [ -n "${PORT:-}" ] && ok "PORT set" || wa "PORT not set (defaults to 3001)"
  [ -n "${JWT_SECRET:-}" ] && ok "JWT_SECRET set" || wa "JWT_SECRET not set (dev fallback in code)"
  [ -n "${JWT_REFRESH_SECRET:-}" ] && ok "JWT_REFRESH_SECRET set" || wa "JWT_REFRESH_SECRET not set (falls back to JWT_SECRET)"
else
  require_non_empty PORT
  require_not_default_like JWT_SECRET
  require_not_default_like JWT_REFRESH_SECRET

  strict="$(echo "${VALIDATION_STRICT_ENABLED:-}" | tr '[:upper:]' '[:lower:]' | xargs)"
  if [ "$strict" = "1" ] || [ "$strict" = "true" ] || [ "$strict" = "yes" ] || [ "$strict" = "on" ]; then
    ok "VALIDATION_STRICT_ENABLED enabled"
  else
    ng "VALIDATION_STRICT_ENABLED must be enabled"
  fi

  rate="$(echo "${RATE_LIMIT_ENABLED:-}" | tr '[:upper:]' '[:lower:]' | xargs)"
  if [ "$rate" = "1" ] || [ "$rate" = "true" ] || [ "$rate" = "yes" ] || [ "$rate" = "on" ]; then
    ok "RATE_LIMIT_ENABLED enabled"
  else
    ng "RATE_LIMIT_ENABLED must be enabled"
  fi

  forbid_enabled DEV_SEED
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "❌ diag-env-matrix FAILED"
  exit 1
fi

if [ "$warn" -ne 0 ]; then
  echo "⚠️  diag-env-matrix OK with warnings"
else
  echo "✅ diag-env-matrix OK"
fi
