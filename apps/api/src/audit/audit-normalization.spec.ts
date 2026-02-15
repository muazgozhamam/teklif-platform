import {
  canonicalizeAction,
  canonicalizeEntity,
  resolveActionFilterCandidates,
  resolveAlias,
} from './audit-normalization';

describe('audit normalization', () => {
  describe('idempotency', () => {
    it('canonicalizeAction is idempotent for canonical actions', () => {
      const canonicalActions = [
        'LEAD_CREATED',
        'LEAD_STATUS_CHANGED',
        'DEAL_CREATED',
        'DEAL_ASSIGNED',
        'DEAL_STATUS_CHANGED',
        'LISTING_UPSERTED',
        'LISTING_PUBLISHED',
        'LISTING_SOLD',
        'USER_CREATED',
        'USER_PATCHED',
        'USER_PASSWORD_SET',
        'COMMISSION_SNAPSHOT_CREATED',
        'COMMISSION_SNAPSHOT_NETWORK_CAPTURED',
        'LOGIN_DENIED_INACTIVE',
        'NETWORK_PARENT_SET',
        'COMMISSION_SPLIT_CONFIG_SET',
        'REGION_CREATED',
        'OFFICE_CREATED',
        'USER_OFFICE_ASSIGNED',
        'LEAD_REGION_ASSIGNED',
        'COMMISSION_ALLOCATED',
        'COMMISSION_ALLOCATION_APPROVED',
        'COMMISSION_ALLOCATION_VOIDED',
        'COMMISSION_ALLOCATION_EXPORTED',
        'COMMISSION_CONFIG_PATCHED',
      ];

      for (const action of canonicalActions) {
        expect(canonicalizeAction(action)).toBe(action);
      }
    });

    it('canonicalizeEntity is idempotent for canonical entities', () => {
      const canonicalEntities = ['LEAD', 'DEAL', 'LISTING', 'REGION', 'OFFICE', 'USER', 'COMMISSION_CONFIG', 'AUTH'];
      for (const entity of canonicalEntities) {
        expect(canonicalizeEntity(entity)).toBe(entity);
      }
    });
  });

  describe('alias resolution', () => {
    it('maps commission aliases to COMMISSION_CONFIG_PATCHED', () => {
      expect(canonicalizeAction('COMMISSION_UPDATED')).toBe('COMMISSION_CONFIG_PATCHED');
      expect(canonicalizeAction('COMMISSION_CONFIG_UPDATED')).toBe('COMMISSION_CONFIG_PATCHED');
    });

    it('breaks alias cycles defensively and returns last resolved value', () => {
      const cycleMap = { A: 'B', B: 'A' };
      expect(resolveAlias('A', 5, cycleMap)).toBe('B');
    });

    it('respects depth limit and returns last resolved value', () => {
      const longMap = { A: 'B', B: 'C', C: 'D', D: 'E', E: 'F', F: 'G' };
      expect(resolveAlias('A', 2, longMap)).toBe('C');
    });
  });

  describe('backward filter semantics', () => {
    it('matches raw legacy action query', () => {
      expect(resolveActionFilterCandidates('ADMIN_COMMISSION_PATCHED')).toContain('ADMIN_COMMISSION_PATCHED');
    });

    it('matches canonical action query', () => {
      expect(resolveActionFilterCandidates('COMMISSION_CONFIG_PATCHED')).toContain('ADMIN_COMMISSION_PATCHED');
    });

    it('matches alias query', () => {
      expect(resolveActionFilterCandidates('COMMISSION_UPDATED')).toContain('ADMIN_COMMISSION_PATCHED');
    });
  });

  it('normalizes legacy entity COMMISSION to COMMISSION_CONFIG', () => {
    expect(canonicalizeEntity('COMMISSION')).toBe('COMMISSION_CONFIG');
  });
});
