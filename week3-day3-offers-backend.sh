#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SRC_DIR="$API_DIR/src"
PRISMA_SCHEMA="$API_DIR/prisma/schema.prisma"

echo "==> Root: $ROOT"
echo "==> API:  $API_DIR"

# Basic checks
if [ ! -d "$API_DIR" ]; then
  echo "ERROR: apps/api bulunamadı. Proje kökünde misin?"
  exit 1
fi

if [ ! -f "$PRISMA_SCHEMA" ]; then
  echo "ERROR: Prisma schema bulunamadı: $PRISMA_SCHEMA"
  exit 1
fi

# 1) Prisma schema patch (append only if not exists)
if grep -q "model Offer" "$PRISMA_SCHEMA"; then
  echo "==> Prisma: model Offer zaten var. Atlıyorum."
else
  echo "==> Prisma: OfferStatus enum + Offer model ekleniyor (append)."
  cat >> "$PRISMA_SCHEMA" <<'PRISMA'

//
// Week3–Day3: Offers
// NOT: Eğer sende Request model adı farklıysa, aşağıdaki "Request" kısmını kendi model adınla değiştir.
//
enum OfferStatus {
  PENDING
  ACCEPTED
  REJECTED
}

model Offer {
  id            String      @id @default(cuid())
  requestId     String
  providerId    String

  price         Int
  description   String?
  estimatedTime String?

  status        OfferStatus @default(PENDING)

  createdAt     DateTime    @default(now())
  updatedAt     DateTime    @updatedAt

  // Relations
  request       Request     @relation(fields: [requestId], references: [id], onDelete: Cascade)

  @@index([requestId])
  @@index([providerId])
  @@unique([requestId, providerId])
}
PRISMA
fi

# 2) Create folders
mkdir -p "$SRC_DIR/offers/dto"

# 3) Create DTOs
cat > "$SRC_DIR/offers/dto/create-offer.dto.ts" <<'TS'
import { IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';

export class CreateOfferDto {
  @IsString()
  @IsNotEmpty()
  requestId!: string;

  @IsInt()
  @Min(0)
  price!: number;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  estimatedTime?: string;
}
TS

cat > "$SRC_DIR/offers/dto/update-offer-status.dto.ts" <<'TS'
import { IsEnum } from 'class-validator';

export enum OfferStatusDto {
  PENDING = 'PENDING',
  ACCEPTED = 'ACCEPTED',
  REJECTED = 'REJECTED',
}

export class UpdateOfferStatusDto {
  @IsEnum(OfferStatusDto)
  status!: OfferStatusDto;
}
TS

# 4) Offers service
cat > "$SRC_DIR/offers/offers.service.ts" <<'TS'
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { OfferStatusDto, UpdateOfferStatusDto } from './dto/update-offer-status.dto';

@Injectable()
export class OffersService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * providerId: auth’dan gelecek (şimdilik parametre)
   */
  async create(providerId: string, dto: CreateOfferDto) {
    // Aynı provider aynı request'e 1 teklif kuralı (DB unique var ama daha iyi mesaj)
    const existing = await this.prisma.offer.findUnique({
      where: {
        requestId_providerId: {
          requestId: dto.requestId,
          providerId,
        },
      },
    });

    if (existing) {
      throw new BadRequestException('Bu talebe zaten teklif verdiniz.');
    }

    // Request var mı? (Request model adı sende farklıysa burada patlar)
    // Eğer sende Request tablosu farklı ise, bu blok düzenlenecek.
    const req = await this.prisma.request.findUnique({
      where: { id: dto.requestId },
      select: { id: true },
    });

    if (!req) throw new NotFoundException('Talep bulunamadı.');

    return this.prisma.offer.create({
      data: {
        requestId: dto.requestId,
        providerId,
        price: dto.price,
        description: dto.description,
        estimatedTime: dto.estimatedTime,
        status: 'PENDING',
      },
    });
  }

  async listByRequest(requestId: string) {
    return this.prisma.offer.findMany({
      where: { requestId },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * customerId: auth’dan gelecek (şimdilik parametre)
   * Kabul edilirse diğer teklifler otomatik REJECTED
   * Request CLOSED yapılacak (sende request status alanı yoksa bu kısmı no-op bırakırız)
   */
  async updateStatus(customerId: string, offerId: string, dto: UpdateOfferStatusDto) {
    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
    });

    if (!offer) throw new NotFoundException('Teklif bulunamadı.');

    // Bu noktada normalde:
    // - customerId'nin bu request'in sahibi olduğunu doğrularız.
    // Şimdilik iskelet: customer doğrulaması yok.
    if (!customerId) {
      throw new ForbiddenException('Yetkisiz işlem.');
    }

    if (dto.status === OfferStatusDto.ACCEPTED) {
      // Transaction: 1) seçilen offer ACCEPTED, 2) diğerleri REJECTED
      return this.prisma.$transaction(async (tx) => {
        const accepted = await tx.offer.update({
          where: { id: offerId },
          data: { status: 'ACCEPTED' },
        });

        await tx.offer.updateMany({
          where: {
            requestId: offer.requestId,
            id: { not: offerId },
            status: { in: ['PENDING'] },
          },
          data: { status: 'REJECTED' },
        });

        // Request'i CLOSED yapmak (sende alan yoksa burayı yorumla)
        // await tx.request.update({
        //   where: { id: offer.requestId },
        //   data: { status: 'CLOSED' },
        // });

        return accepted;
      });
    }

    // REJECTED veya PENDING
    return this.prisma.offer.update({
      where: { id: offerId },
      data: { status: dto.status },
    });
  }
}
TS

# 5) Offers controller
cat > "$SRC_DIR/offers/offers.controller.ts" <<'TS'
import { Body, Controller, Get, Patch, Post, Query } from '@nestjs/common';
import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { UpdateOfferStatusDto } from './dto/update-offer-status.dto';

@Controller('offers')
export class OffersController {
  constructor(private readonly offersService: OffersService) {}

  // NOT: Şimdilik providerId/customerId header’dan alıyoruz (temiz MVP).
  // Sonra JWT ile otomatik gelecek.
  @Post()
  async create(
    @Query('providerId') providerId: string,
    @Body() dto: CreateOfferDto,
  ) {
    return this.offersService.create(providerId || 'provider_demo', dto);
  }

  @Get()
  async listByRequest(@Query('requestId') requestId: string) {
    return this.offersService.listByRequest(requestId);
  }

  @Patch('status')
  async updateStatus(
    @Query('customerId') customerId: string,
    @Query('offerId') offerId: string,
    @Body() dto: UpdateOfferStatusDto,
  ) {
    return this.offersService.updateStatus(customerId || 'customer_demo', offerId, dto);
  }
}
TS

# 6) Offers module
cat > "$SRC_DIR/offers/offers.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OffersController } from './offers.controller';
import { OffersService } from './offers.service';

@Module({
  controllers: [OffersController],
  providers: [OffersService, PrismaService],
  exports: [OffersService],
})
export class OffersModule {}
TS

# 7) Register OffersModule in app.module.ts (best-effort patch)
APP_MODULE="$SRC_DIR/app.module.ts"
if [ -f "$APP_MODULE" ]; then
  if grep -q "OffersModule" "$APP_MODULE"; then
    echo "==> app.module.ts: OffersModule zaten ekli. Atlıyorum."
  else
    echo "==> app.module.ts: OffersModule import + module list'e ekleniyor."

    # add import line (after other imports)
    # if there's an import section at top, we append a new import after last import
    perl -0777 -i -pe 's|(import\s+.*?;\s*\n)(?!.*OffersModule)|$1import { OffersModule } from "./offers/offers.module";\n|s' "$APP_MODULE"

    # add to @Module imports array
    perl -0777 -i -pe 's|imports:\s*\[|imports: [OffersModule, |s' "$APP_MODULE"
  fi
else
  echo "WARN: app.module.ts bulunamadı. OffersModule'u elle eklemen gerekebilir."
fi

echo "==> Done. Şimdi migration + generate çalıştıracağız."

# 8) Prisma migrate + generate
pnpm --filter api prisma migrate dev --name add_offer
pnpm --filter api prisma generate

echo "==> Completed."
echo ""
echo "TEST:"
echo "1) API'yi çalıştır"
echo "2) POST /offers?providerId=provider_demo  body: {\"requestId\":\"...\",\"price\":1000}"
