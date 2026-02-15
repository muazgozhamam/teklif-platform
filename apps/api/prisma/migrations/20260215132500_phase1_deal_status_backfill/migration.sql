-- Phase 1.3 backfill: normalize legacy READY_FOR_MATCHING to READY_FOR_LISTING

UPDATE "Deal"
SET "status" = 'READY_FOR_LISTING'::"DealStatus"
WHERE "status" = 'READY_FOR_MATCHING'::"DealStatus";
