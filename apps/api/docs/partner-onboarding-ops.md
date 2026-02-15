# Partner Onboarding Ops (FAZ 9.5)

## Goal
Partner onboarding durumunu role-bazlı checklist ile görünür kılmak ve admin tarafında toplu takip edebilmek.

## Endpoints
- `GET /onboarding/me` (JWT required)
  - Desteklenen roller: `HUNTER`, `BROKER`, `CONSULTANT`
  - Response:
    - `supported`: rol onboarding kapsamındaysa `true`
    - `completionPct`: yüzde tamamlama
    - `checklist`: role-specific adımlar + `done`
    - `signals`: sayısal sinyaller (`leadCount`, `leadApprovedCount`, `listingCount`)
- `GET /admin/onboarding/users?role=&take=&skip=` (ADMIN)
  - Role filtreli, paginated onboarding listesi.
  - Response: `{ items, total, take, skip, role }`

## Checklist Logic (MVP)
- `HUNTER`:
  - account active
  - profile basics
  - first lead created
- `BROKER`:
  - account active
  - office assigned
  - first lead approved
- `CONSULTANT`:
  - account active
  - office assigned
  - first listing created

## Validation
- Unit: `apps/api/src/onboarding/onboarding.service.spec.ts`
- Runtime smoke: `scripts/smoke-onboarding.sh`

## Notes
- Bu katman read-model odaklıdır; core Lead->Deal->Listing davranışını değiştirmez.
- Backward compatibility korunur; yeni endpointler eklenmiştir, mevcut endpoint davranışı değişmemiştir.
