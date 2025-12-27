#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"
SERVICE="$API_DIR/src/offers/offers.service.ts"

if [ ! -f "$SCHEMA" ]; then
  echo "ERROR: schema.prisma not found: $SCHEMA"
  exit 1
fi

if [ ! -f "$SERVICE" ]; then
  echo "ERROR: offers.service.ts not found: $SERVICE"
  exit 1
fi

echo "==> 1) Prisma: Add Offer -> Lead relation"

# Offer bloğunda daha önce kalmış "request Lead" yoksa ekle
# - requestId zaten var
# - relation satırını "request Lead" olarak ekleyeceğiz
perl -0777 -i -pe '
if ($ARGV[0]) {}
s/(model\s+Offer\s*\{.*?\n)(\s*\/\/ Relations\s*\n)/$1$2/s;
' "$SCHEMA"

# Offer bloğu içinde "requestId" var; " // Relations" altına relation ekle
# Eğer zaten "request Lead" varsa dokunma
my $schema;
$schema = do { local $/; open my $fh, "<", $SCHEMA or die $!; <$fh> };
if ($schema !~ /model\s+Offer\s*\{[\s\S]*?\n\s*request\s+Lead\s+@relation\(/) {
  perl -0777 -i -pe '
  s/(model\s+Offer\s*\{[\s\S]*?\n\s*\/\/ Relations\s*\n)/$1  request       Lead        @relation(fields: [requestId], references: [id], onDelete: Cascade)\n\n/s
  ' "$SCHEMA"
  echo "==> Added: request Lead @relation(...)"
else
  echo "==> Offer.request relation already exists, skipping."
fi

echo "==> 2) OffersService: Reinstate Lead existence check + update Lead on ACCEPTED"

# 2.1 create() içinde Lead check ekle (yoksa)
# "const req = await this.prisma.lead.findUnique" yoksa ekle
if ! grep -q "this\.prisma\.lead\.findUnique" "$SERVICE"; then
  perl -0777 -i -pe '
  s/(async\s+create\([^\)]*\)\s*\{\s*\n)/$1    const lead = await this.prisma.lead.findUnique({ where: { id: dto.requestId }, select: { id: true } });\n    if (!lead) throw new NotFoundException("Talep (Lead) bulunamadı.");\n\n/s
  ' "$SERVICE"
  echo "==> Added Lead existence check to create()"
else
  echo "==> Lead check already present in create(), skipping."
fi

# 2.2 ACCEPTED transaction içine Lead status update ekle (yoksa)
# tx.offer.updateMany bloğundan sonra lead update ekle
if ! grep -q "tx\.lead\.update" "$SERVICE"; then
  perl -0777 -i -pe '
  s/(await\s+tx\.offer\.updateMany\([\s\S]*?\);\s*\n\n\s*\/\/ Request\'i CLOSED yapmak[\s\S]*?\n)/$1        // Lead status update (MVP: teklif kabul edildi)\n        await tx.lead.update({\n          where: { id: offer.requestId },\n          data: { status: "ACTIVE" },\n        });\n\n/s
  ' "$SERVICE"
  # Eğer "Request'i CLOSED" yorumu artık yoksa, accepted dönüşünden önce eklemeye çalış
  perl -0777 -i -pe '
  s/(await\s+tx\.offer\.updateMany\([\s\S]*?\);\s*\n\s*\n\s*return\s+accepted;)/$1\n\n        await tx.lead.update({ where: { id: offer.requestId }, data: { status: "ACTIVE" } });\n\n/s
  ' "$SERVICE"
  echo "==> Added Lead update on ACCEPTED"
else
  echo "==> Lead update already present, skipping."
fi

echo "==> 3) Prisma validate + migrate"

cd "$API_DIR"
pnpm exec prisma validate
pnpm exec prisma migrate dev --name link_offer_to_lead
pnpm exec prisma generate

echo "==> Done. Restart API after this."
