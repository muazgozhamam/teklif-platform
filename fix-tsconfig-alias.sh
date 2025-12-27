#!/usr/bin/env bash
set -e

API=apps/api

echo "==> tsconfig.paths.json yaziliyor"

cat <<'JSON' > $API/tsconfig.paths.json
{
  "compilerOptions": {
    "baseUrl": "./src",
    "paths": {
      "@/*": ["*"]
    }
  }
}
JSON

echo "==> tsconfig.json paths'e baglaniyor"

perl -0777 -i -pe '
  s/"extends":\s*"[^"]*"/"extends": "./tsconfig.paths.json"/
' $API/tsconfig.json

echo "==> tsconfig alias TAMAM"
