#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 1) DTO patch: key optional + transform fallback field
DTO_FILE="$ROOT/apps/api/src/leads/dto/lead-answer.dto.ts"
[ -f "$DTO_FILE" ] || { echo "❌ DTO bulunamadı"; exit 1; }

cp "$DTO_FILE" "$DTO_FILE.keyfinal.bak"
sed -i '' 's/@IsString\(\)\s*@IsNotEmpty\(\)\s*key\s*:\s*string;/@IsString()\nkey?: string;/' "$DTO_FILE"
sed -i '' '/key?: string;/!b;n;c\@Transform(({value,obj}) => value ?? obj?.field ?? "")' "$DTO_FILE"
echo "✅ DTO patched: key optional + transform fallback field -> key"

# 2) next-question return patch
SERVICE_FILE="$ROOT/apps/api/src/leads/leads.service.ts"
[ -f "$SERVICE_FILE" ] || { echo "❌ leads.service.ts bulunamadı"; exit 1; }

cp "$SERVICE_FILE" "$SERVICE_FILE.keyfinal.bak"
sed -i '' 's/return { done: false, field, question }/return { done: false, key: field, field, question }/' "$SERVICE_FILE"
echo "✅ next-question return patched: key added"

# 3) Build API
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Build done"
