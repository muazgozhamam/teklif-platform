import { NextRequest } from 'next/server';
import { truncateToTwoSentences } from '@/lib/chat/sentenceLimit';
import {
  getConversationState,
  resolveIdentity,
  saveConversationState,
  type ChatIntent,
} from '@/lib/chat/funnelState';
import { submittedMessage } from '@/lib/chat/funnelPolicy';

export const runtime = 'nodejs';

type Payload = {
  intent?: unknown;
  data?: unknown;
};

function makeJson(body: Record<string, unknown>, status: number, setCookie?: string) {
  const headers = new Headers({ 'content-type': 'application/json; charset=utf-8' });
  if (setCookie) headers.append('set-cookie', setCookie);
  return new Response(JSON.stringify(body), { status, headers });
}

function validIntent(intent: unknown): intent is ChatIntent {
  return (
    intent === 'CONSULTANT_APPLY' ||
    intent === 'HUNTER_APPLY' ||
    intent === 'OWNER_SELL' ||
    intent === 'OWNER_RENT' ||
    intent === 'INVESTOR' ||
    intent === 'GENERIC'
  );
}

export async function POST(req: NextRequest) {
  let payload: Payload;
  try {
    payload = (await req.json()) as Payload;
  } catch {
    return makeJson({ ok: false, message: truncateToTwoSentences('Geçersiz form verisi. Lütfen yeniden gönder.') }, 400);
  }

  if (!validIntent(payload.intent)) {
    return makeJson({ ok: false, message: truncateToTwoSentences('Form intent bilgisi eksik. Lütfen tekrar deneyin.') }, 400);
  }

  if (!payload.data || typeof payload.data !== 'object') {
    return makeJson({ ok: false, message: truncateToTwoSentences('Form alanları eksik. Lütfen zorunlu alanları doldurun.') }, 400);
  }

  const identity = resolveIdentity(req);
  const state = getConversationState(identity);
  state.formStatus = 'SUBMITTED';
  state.step = 'QUALIFICATION';
  state.intent = payload.intent;
  state.intentConfidence = Math.max(state.intentConfidence, 0.85);
  saveConversationState(identity, state);

  const msg = submittedMessage(payload.intent);
  return makeJson({ ok: true, message: msg }, 201, identity.setAnonCookie || undefined);
}
