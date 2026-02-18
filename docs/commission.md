# SatDedi Commission (Hakediş) - Faz 1

## Temel Kurallar
- `CommissionSnapshot` immutable kabul edilir.
- Finansal doğruluk kaynağı `CommissionLedgerEntry` tablosudur.
- Silme yapılmaz, düzeltme `REVERSAL` / `ADJUSTMENT` ile yapılır.
- `idempotencyKey` ile snapshot oluşturma idempotenttir.
- Maker-checker: oluşturan kullanıcı onaylayamaz (override hariç).
- Base amount precedence:
  1. `closeSummary.commissionBaseAmount` (lead answer key üzerinden)
  2. `listing.price`
  3. `deal.salePrice` (modelde mevcut değilse TODO)
  4. hiçbiri yoksa snapshot oluşturma engellenir (`Base Amount Missing`)

## Yaşam Döngüsü
1. Deal `WON` olunca admin snapshot oluşturur.
2. Snapshot `PENDING_APPROVAL` durumda oluşur.
3. Admin/Broker onaylar => `APPROVED`.
4. Payout kaydı ile ledger'a `PAYOUT/DEBIT` düşülür.
5. Reverse işlemi ledger'a `REVERSAL/DEBIT` ekler ve snapshot `REVERSED` olur.

## Faz 3 Ekleri
- Period lock:
  - `GET /admin/commission/period-locks`
  - `POST /admin/commission/period-locks`
  - `POST /admin/commission/period-locks/:lockId/release`
- Dispute SLA escalation:
  - `POST /admin/commission/disputes/escalate-overdue`
  - `POST /admin/commission/disputes/:disputeId/resolve` (`/status` ile aynı işlevsel endpoint)

### Period Lock Kuralı
- Aktif kilit dönemine denk gelen işlemler engellenir:
  - snapshot create
  - snapshot approve
  - payout create
  - reverse

### Audit Trail (CommissionAuditEvent)
- Snapshot, payout, dispute ve period lock işlemlerinde audit event üretilir.
- Amaç: denetlenebilirlik ve incident sonrası iz sürme.

## Para Hesabı
- Tutarlar `minor units` (kuruş) olarak `BigInt` tutulur.
- `poolAmountMinor` hesaplaması:
  - `PERCENTAGE`: policy `roundingRule` kullanılarak hesaplanır (`ROUND_HALF_UP` / `BANKERS`)
  - `FIXED`: `fixedCommissionMinor`
- Allocation dağıtımı deterministic largest-remainder yöntemiyle yapılır.
- Kalan fark (teorik sapma) varsa `SYSTEM` satırına yazılır.

## Overview Formülü
- `totalEarned` = `EARN/CREDIT` toplamı
- `totalPaid` = `PAYOUT/DEBIT` toplamı
- `totalReversed` = `REVERSAL/DEBIT` toplamı
- `outstanding` = `earned - paid - reversed`
