# (#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"

echo "==> 1) DTO patch: key optional + transform fallback"
DTO_FILE="$ROOT/apps/api/src/leads/dto/lead-answer.dto.ts"
[ -f "$DTO_FILE" ] || { echo "❌ DTO bulunamadı: $DTO_FILE"; exit 1; }

cp "$DTO_FILE" "$DTO_FILE.keyfinal.bak"

# key optional + @Transform
sed -i "" 's/@IsString()[[:space:]]*@IsNotEmpty()[[:space:]]*key[[:space:]]*:[[:space:]]*string;/@IsString()\n@IsOptional()\n@Transform(({value,obj}) => value ?? obj?.field ?? "")\nkey?: string;/' "$DTO_FILE"

echo "✅ DTO patched: key optional + transform fallback -> key"

echo "==> 2) next-question return patch"
SERVICE_FILE="$ROOT/apps/api/src/leads/leads.service.ts"
[ -f "$SERVICE_FILE" ] || { echo "❌ leads.service.ts bulunamadı: $SERVICE_FILE"; exit 1; }

cp "$SERVICE_FILE" "$SERVICE_FILE.keyfinal.bak"

sed -i "" 's/return { done: false, field, question }/return { done: false, key: field, field, question }/' "$SERVICE_FILE"

echo "✅ next-question return patched: key added"

echo "==> 3) Smoke script POST body patch"
SMOKE="$ROOT/scripts/smoke-wizard-to-match-mac.sh"
[ -f "$SMOKE" ] || { echo "❌ Smoke script bulunamadı: $SMOKE"; exit 1; }

cp "$SMOKE" "$SMOKE.keyfieldanswer.bak"

# answer fallback -> key + field + answer
sed -i '' 's/-d "{\\"answer\\":\\"$A\\"}"/-d "{\\"key\\":\\"$FIELD\\",\\"field\\":\\"$FIELD\\",\\"answer\\":\\"$A\\"}"/' "$SMOKE"

echo "✅ Smoke script patched: wizard/answer -> send key + field + answer"

echo "==> 4) Build API"
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Build done"

echo "✅ Tüm patch’ler uygulandı."
)
