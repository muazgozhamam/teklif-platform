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

type PublicApplicationType =
  | 'CUSTOMER_LEAD'
  | 'PORTFOLIO_LEAD'
  | 'CONSULTANT_CANDIDATE'
  | 'HUNTER_CANDIDATE'
  | 'CORPORATE_LEAD';

function makeJson(body: Record<string, unknown>, status: number, setCookie?: string) {
  const headers = new Headers({ 'content-type': 'application/json; charset=utf-8' });
  if (setCookie) headers.append('set-cookie', setCookie);
  return new Response(JSON.stringify(body), { status, headers });
}

function validIntent(intent: unknown): intent is ChatIntent {
  return (
    intent === 'CONSULTANT_APPLY' ||
    intent === 'HUNTER_APPLY' ||
    intent === 'BUYER_HOME' ||
    intent === 'OWNER_SELL' ||
    intent === 'OWNER_RENT' ||
    intent === 'INVESTOR' ||
    intent === 'GENERIC'
  );
}

function resolveApiBase() {
  const base =
    process.env.NEXT_PUBLIC_API_BASE_URL ||
    process.env.NEXT_PUBLIC_API_URL ||
    process.env.API_URL ||
    'http://localhost:3001';
  return base.replace(/\/+$/, '');
}

function mapIntentToApplicationType(intent: ChatIntent): PublicApplicationType {
  if (intent === 'CONSULTANT_APPLY') return 'CONSULTANT_CANDIDATE';
  if (intent === 'HUNTER_APPLY') return 'HUNTER_CANDIDATE';
  if (intent === 'BUYER_HOME') return 'CUSTOMER_LEAD';
  if (intent === 'INVESTOR') return 'CORPORATE_LEAD';
  return 'PORTFOLIO_LEAD';
}

function splitCityDistrict(raw: string) {
  const text = String(raw || '').trim();
  if (!text) return { city: undefined, district: undefined };
  const chunks = text.split(/[\/,-]/).map((s) => s.trim()).filter(Boolean);
  return {
    city: chunks[0] || undefined,
    district: chunks[1] || undefined,
  };
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

  const formData = payload.data as Record<string, unknown>;
  const fullName = String(formData.fullName || '').trim();
  const phone = String(formData.phone || '').trim();
  if (!fullName || !phone) {
    return makeJson({ ok: false, message: truncateToTwoSentences('Ad soyad ve telefon zorunludur.') }, 400);
  }

  const { city, district } = splitCityDistrict(String(formData.cityDistrict || ''));
  const appType = mapIntentToApplicationType(payload.intent);
  const apiBase = resolveApiBase();

  try {
    const upstream = await fetch(`${apiBase}/public/applications`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        type: appType,
        fullName,
        phone,
        email: String(formData.email || '').trim() || undefined,
        city,
        district,
        notes: String(formData.note || '').trim() || undefined,
        source: 'chat-form',
        data: formData,
      }),
      cache: 'no-store',
    });
    if (!upstream.ok) {
      const text = await upstream.text().catch(() => '');
      return makeJson(
        { ok: false, message: truncateToTwoSentences(`Form kaydı alınamadı. ${text || 'Lütfen tekrar deneyin.'}`) },
        upstream.status || 502,
      );
    }
  } catch {
    return makeJson({ ok: false, message: truncateToTwoSentences('Form servisine bağlanılamadı. Lütfen tekrar deneyin.') }, 502);
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
