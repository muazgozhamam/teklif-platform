# SatDedi Commission (Hakediş) - Faz 1

## Temel Kurallar
- `CommissionSnapshot` immutable kabul edilir.
- Finansal doğruluk kaynağı `CommissionLedgerEntry` tablosudur.
- Silme yapılmaz, düzeltme `REVERSAL` / `ADJUSTMENT` ile yapılır.
- `idempotencyKey` ile snapshot oluşturma idempotenttir.
- Maker-checker: oluşturan kullanıcı onaylayamaz (override hariç).

## Yaşam Döngüsü
1. Deal `WON` olunca admin snapshot oluşturur.
2. Snapshot `PENDING_APPROVAL` durumda oluşur.
3. Admin/Broker onaylar => `APPROVED`.
4. Payout kaydı ile ledger'a `PAYOUT/DEBIT` düşülür.
5. Reverse işlemi ledger'a `REVERSAL/DEBIT` ekler ve snapshot `REVERSED` olur.

## Para Hesabı
- Tutarlar `minor units` (kuruş) olarak `BigInt` tutulur.
- `poolAmountMinor` hesaplaması:
  - `PERCENTAGE`: `baseAmountMinor * rateBp / 10000`
  - `FIXED`: `fixedCommissionMinor`
- Dağıtımda kalan kuruş farkı deterministik olarak CONSULTANT (yoksa son satır) payına eklenir.

## Overview Formülü
- `totalEarned` = `EARN/CREDIT` toplamı
- `totalPaid` = `PAYOUT/DEBIT` toplamı
- `totalReversed` = `REVERSAL/DEBIT` toplamı
- `outstanding` = `earned - paid - reversed`
