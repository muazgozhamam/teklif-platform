# Audit Contract (Backward Compatible)

## Response fields

Audit list endpoints return both raw and normalized values:

- `action`: raw stored enum value from `AuditLog.action`
- `canonicalAction`: normalized action for stable client behavior
- `entity`: raw stored enum value from `AuditLog.entityType`
- `canonicalEntity`: normalized entity for stable client behavior

Existing fields like `entityType` are still returned for backward compatibility.

## Filtering rules

For action filters (`action` query param):

- Match when `raw action == query`
- Match when `canonicalAction == query`
- Match alias values that resolve to canonical action

Example:

- Stored raw: `ADMIN_COMMISSION_PATCHED`
- Query `action=ADMIN_COMMISSION_PATCHED` -> matches
- Query `action=COMMISSION_CONFIG_PATCHED` -> matches
- Query `action=COMMISSION_UPDATED` -> matches (alias)

## Supported aliases

- `COMMISSION_UPDATED` -> `COMMISSION_CONFIG_PATCHED`
- `COMMISSION_CONFIG_UPDATED` -> `COMMISSION_CONFIG_PATCHED`

Legacy compatibility:

- `ADMIN_USER_PATCHED` -> canonical `USER_PATCHED`
- `ADMIN_COMMISSION_PATCHED` -> canonical `COMMISSION_CONFIG_PATCHED`

Entity normalization:

- raw `COMMISSION` -> canonical `COMMISSION_CONFIG`
- raw `COMMISSION_CONFIG` -> canonical `COMMISSION_CONFIG`

## Client recommendation

Clients should prefer canonical fields (`canonicalAction`, `canonicalEntity`) for business logic and keep raw fields only for audit/debug display.
