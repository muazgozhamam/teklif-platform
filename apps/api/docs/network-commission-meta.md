# Network Commission Metadata (Feature Flag)

- Flag: `NETWORK_COMMISSIONS_ENABLED`
- Default: `false` (off)

When the flag is enabled, commission snapshot creation path captures optional network metadata into `CommissionSnapshot.networkMeta`.

## Captured shape

```json
{
  "userId": "consultantId",
  "upline": [{ "id": "...", "role": "...", "parentId": "..." }],
  "path": ["consultantId", "parentId", "...rootId"],
  "splitMap": { "USER": null, "ADMIN": null, "BROKER": 15, "CONSULTANT": 70, "HUNTER": 15 },
  "splitTrace": {
    "sourceUserId": "consultantId",
    "sourceUserRole": "CONSULTANT",
    "effectiveSplitPercent": 70,
    "defaultPercent": 0,
    "resolvedAt": "ISO-8601"
  },
  "officeTrace": {
    "sourceUserId": "consultantId",
    "officeId": "officeId-or-null",
    "regionId": "regionId-or-null",
    "overridePercent": 12.5,
    "resolvedAt": "ISO-8601"
  },
  "capturedAt": "ISO-8601"
}
```

## Source of truth for captured network

The captured network is based on `deal.consultantId` (deterministic choice for current commission snapshot semantics).

- If `consultantId` is missing, metadata capture is skipped.
- Commission amount calculation is unchanged.
- No payout distribution is introduced in this step.
- `splitTrace` is trace-only metadata for future payout logic. It does not change current snapshot amount fields.
- `officeTrace` is trace-only metadata for future office-override logic. It does not change current snapshot amount fields.
- If `networkMeta` already exists and `splitTrace` exists, it is not overwritten (first capture wins).
- If `networkMeta` already exists and `officeTrace` exists, it is not overwritten (first capture wins).
