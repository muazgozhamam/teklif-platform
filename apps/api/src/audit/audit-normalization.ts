import { AuditAction, AuditEntityType } from '@prisma/client';

const ACTION_ALIASES: Record<string, string> = {
  COMMISSION_UPDATED: 'COMMISSION_CONFIG_PATCHED',
  COMMISSION_CONFIG_UPDATED: 'COMMISSION_CONFIG_PATCHED',
};

const LEGACY_TO_CANONICAL_ACTION: Record<string, string> = {
  ADMIN_USER_PATCHED: 'USER_PATCHED',
  ADMIN_COMMISSION_PATCHED: 'COMMISSION_CONFIG_PATCHED',
};

const CANONICAL_TO_COMPAT_ACTIONS: Record<string, string[]> = {
  USER_PATCHED: ['USER_PATCHED', 'ADMIN_USER_PATCHED'],
  COMMISSION_CONFIG_PATCHED: ['ADMIN_COMMISSION_PATCHED'],
};

const LEGACY_TO_CANONICAL_ENTITY: Record<string, string> = {
  COMMISSION: 'COMMISSION_CONFIG',
};

export function resolveAlias(
  value: string,
  depthLimit = 5,
  aliasMap: Record<string, string> = ACTION_ALIASES,
): string {
  let current = String(value || '').trim().toUpperCase();
  if (!current) return current;
  const visited = new Set<string>([current]);
  let depth = 0;

  while (depth < depthLimit) {
    const next = aliasMap[current];
    if (!next) return current;
    if (visited.has(next)) return current;
    current = next;
    visited.add(current);
    depth += 1;
  }

  return current;
}

export function canonicalizeAction(value: string, depthLimit = 5): string {
  const resolved = resolveAlias(value, depthLimit);
  return LEGACY_TO_CANONICAL_ACTION[resolved] ?? resolved;
}

export function canonicalizeEntity(value: string): string {
  const up = String(value || '').trim().toUpperCase();
  return LEGACY_TO_CANONICAL_ENTITY[up] ?? up;
}

export function resolveActionFilterCandidates(
  actionOrAlias: string,
  validActions: readonly string[] = Object.values(AuditAction),
): AuditAction[] {
  const resolvedCanonical = canonicalizeAction(actionOrAlias);
  const compat = CANONICAL_TO_COMPAT_ACTIONS[resolvedCanonical] ?? [resolvedCanonical];
  const values = new Set(validActions.map((v) => String(v).toUpperCase()));
  return compat.filter((candidate) => values.has(candidate)) as AuditAction[];
}

export function isKnownEntityType(value: string): boolean {
  const values = new Set<string>(Object.values(AuditEntityType));
  return values.has(String(value || '').trim().toUpperCase());
}

