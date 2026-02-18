import type { NextRequest } from 'next/server';

export type ChatIntent =
  | 'CONSULTANT_APPLY'
  | 'HUNTER_APPLY'
  | 'OWNER_SELL'
  | 'OWNER_RENT'
  | 'INVESTOR'
  | 'GENERIC';

export type FunnelStep = 'DISCOVERY' | 'QUALIFICATION' | 'FORM_TRIGGERED';
export type FormStatus = 'NOT_SHOWN' | 'SHOWN' | 'SUBMITTED';

export type ConversationState = {
  sessionId: string;
  userId: string | null;
  messageCount: number;
  step: FunnelStep;
  intent: ChatIntent | null;
  intentConfidence: number;
  formStatus: FormStatus;
};

type Identity = {
  key: string;
  userId: string | null;
  authenticated: boolean;
  setAnonCookie: string;
};

declare global {
  var satdediConversationStore: Map<string, ConversationState> | undefined;
}

const conversationStore = globalThis.satdediConversationStore ?? new Map<string, ConversationState>();
if (!globalThis.satdediConversationStore) globalThis.satdediConversationStore = conversationStore;

const ANON_ID_COOKIE = 'satdedi_anon_id';

function parseJwtSub(token: string) {
  try {
    const parts = token.split('.');
    if (parts.length < 2) return '';
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const json = Buffer.from(payload, 'base64').toString('utf8');
    const parsed = JSON.parse(json) as { sub?: unknown };
    return typeof parsed.sub === 'string' ? parsed.sub : '';
  } catch {
    return '';
  }
}

function getAuthToken(req: NextRequest) {
  return req.cookies.get('token')?.value || req.cookies.get('access_token')?.value || req.cookies.get('auth_token')?.value || '';
}

function getClientFingerprint(req: NextRequest) {
  const forwardedFor = req.headers.get('x-forwarded-for') || '';
  const ip = forwardedFor.split(',')[0]?.trim() || req.headers.get('x-real-ip') || 'unknown-ip';
  const ua = req.headers.get('user-agent') || 'unknown-ua';
  return `${ip}:${ua.slice(0, 120)}`;
}

export function resolveIdentity(req: NextRequest): Identity {
  const token = getAuthToken(req);
  const userId = parseJwtSub(token);

  if (userId) {
    return {
      key: `auth:${userId}`,
      userId,
      authenticated: true,
      setAnonCookie: '',
    };
  }

  const existingAnonId = req.cookies.get(ANON_ID_COOKIE)?.value;
  const anonId = existingAnonId || `a_${crypto.randomUUID()}`;
  const fallback = getClientFingerprint(req);

  return {
    key: `anon:${anonId}:${fallback}`,
    userId: null,
    authenticated: false,
    setAnonCookie: existingAnonId ? '' : `${ANON_ID_COOKIE}=${anonId}; Path=/; Max-Age=2592000; SameSite=Lax; HttpOnly`,
  };
}

export function getConversationState(identity: Identity): ConversationState {
  const existing = conversationStore.get(identity.key);
  if (existing) return existing;

  const initial: ConversationState = {
    sessionId: identity.key,
    userId: identity.userId,
    messageCount: 0,
    step: 'DISCOVERY',
    intent: null,
    intentConfidence: 0,
    formStatus: 'NOT_SHOWN',
  };

  conversationStore.set(identity.key, initial);
  return initial;
}

export function saveConversationState(identity: Identity, nextState: ConversationState) {
  conversationStore.set(identity.key, nextState);
}
