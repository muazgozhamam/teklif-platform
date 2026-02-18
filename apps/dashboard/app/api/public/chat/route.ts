import { NextRequest } from 'next/server';
import { truncateToTwoSentences } from '@/lib/chat/sentenceLimit';

export const runtime = 'nodejs';

const MAX_GUEST_MESSAGES = 5;
const MAX_AUTH_MESSAGES = 30;
const ANON_ID_COOKIE = 'satdedi_anon_id';

const SALES_INSTRUCTIONS_TR = `Sen SatDedi'nin satış odaklı emlak asistanısın.
Kurallar:
- Sadece emlak/satış/kiralama/danışmanlık/iş ortaklığı bağlamında cevap ver.
- Emlak dışı isteklerde kibarca reddet ve emlak sürecine geri yönlendir.
- Asla rakamsal fiyat, değerleme, TL aralığı, m2 fiyatı verme.
- Her yanıtta en fazla 2 cümle yaz.
- Her yanıtta kısa bir sonraki adım sorusu veya yönlendirmesi ver.
- Ton kısa, net, ikna edici ve satışa yönlendirici olsun.
- Kullanıcıyı SatDedi'de süreci başlatmaya yönlendir.`;

type ChatPayload = {
  message?: unknown;
  history?: unknown;
  messages?: unknown;
};

type UpstreamMessage = { role: 'user' | 'assistant'; content: string };

declare global {
  var satdediUsageStore: Map<string, number> | undefined;
}

const usageStore = globalThis.satdediUsageStore ?? new Map<string, number>();
if (!globalThis.satdediUsageStore) globalThis.satdediUsageStore = usageStore;

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

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

function resolveIdentity(req: NextRequest) {
  const token = getAuthToken(req);
  const userId = parseJwtSub(token);
  if (userId) {
    return {
      key: `auth:${userId}`,
      authenticated: true,
      limit: MAX_AUTH_MESSAGES,
      setAnonCookie: '',
    };
  }

  const existingAnonId = req.cookies.get(ANON_ID_COOKIE)?.value;
  const anonId = existingAnonId || `a_${crypto.randomUUID()}`;
  const fallback = getClientFingerprint(req);

  return {
    key: `anon:${anonId}:${fallback}`,
    authenticated: false,
    limit: MAX_GUEST_MESSAGES,
    setAnonCookie: existingAnonId ? '' : `${ANON_ID_COOKIE}=${anonId}; Path=/; Max-Age=2592000; SameSite=Lax; HttpOnly`,
  };
}

function extractMessages(payload: ChatPayload): UpstreamMessage[] {
  if (Array.isArray(payload.messages)) {
    return payload.messages
      .map((item) => {
        if (!item || typeof item !== 'object') return null;
        const roleRaw = (item as { role?: unknown }).role;
        const contentRaw = (item as { content?: unknown }).content;
        if ((roleRaw !== 'user' && roleRaw !== 'assistant') || typeof contentRaw !== 'string') return null;
        const content = contentRaw.trim();
        if (!content) return null;
        return { role: roleRaw, content } as UpstreamMessage;
      })
      .filter((item): item is UpstreamMessage => Boolean(item));
  }

  const historyMessages = Array.isArray(payload.history)
    ? payload.history
        .map((item) => {
          if (!item || typeof item !== 'object') return null;
          const roleRaw = (item as { role?: unknown }).role;
          const contentRaw = (item as { content?: unknown }).content;
          if ((roleRaw !== 'user' && roleRaw !== 'assistant') || typeof contentRaw !== 'string') return null;
          const content = contentRaw.trim();
          if (!content) return null;
          return { role: roleRaw, content } as UpstreamMessage;
        })
        .filter((item): item is UpstreamMessage => Boolean(item))
    : [];

  const message = typeof payload.message === 'string' ? payload.message.trim() : '';
  if (message) historyMessages.push({ role: 'user', content: message });
  return historyMessages;
}

function getLatestUserMessage(messages: UpstreamMessage[]) {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    if (messages[i].role === 'user') return messages[i].content;
  }
  return '';
}

function isRealEstateTopic(text: string) {
  return /(ev|daire|arsa|tarla|emlak|sat|kirala|kiralık|satılık|mülk|danışman|iş ortağı|portföy|ilan|tapu|ofis|dükkan|konut|ticari|devir)/i.test(
    text,
  );
}

function normalizeTwoSentenceReply(raw: string, userText: string) {
  const compact = raw.replace(/\s+/g, ' ').trim();

  if (/(\d|₺|\bTL\b|\baralık\b|\bm2\b|\bmetrekare\b)/i.test(compact) || /fiyat|değer|m2/i.test(userText)) {
    return truncateToTwoSentences('Net fiyat veremem. SatDedi\'de ücretsiz analiz başlatalım, mülk türü ve konumu paylaşır mısın?');
  }

  if (!isRealEstateTopic(userText)) {
    return truncateToTwoSentences('Bu konuda yardımcı olamam. Emlak satışı veya kiralama için mülk türü ve konumu paylaşır mısın?');
  }

  if (!compact) {
    return truncateToTwoSentences('SatDedi\'de süreci hemen başlatabiliriz. Mülk türü ve konumu nedir?');
  }

  const twoSentence = truncateToTwoSentences(compact);
  if (/[?؟]$/.test(twoSentence)) return twoSentence;
  return truncateToTwoSentences(`${twoSentence} Mülk türü ve konumu nedir?`);
}

function chunkText(text: string) {
  const words = text.split(' ');
  const chunks: string[] = [];
  let current = '';

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length >= 20) {
      chunks.push(candidate);
      current = '';
    } else {
      current = candidate;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

async function fetchOpenAI(messages: UpstreamMessage[], signal: AbortSignal) {
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey) throw new Error('OPENAI_API_KEY missing');

  const model = process.env.OPENAI_CHAT_MODEL?.trim() || 'gpt-5-mini';
  const promptId = process.env.OPENAI_PROMPT_ID?.trim();

  const body: Record<string, unknown> = {
    model,
    instructions: SALES_INSTRUCTIONS_TR,
    input: messages.slice(-10).map((m) => ({ role: m.role, content: m.content })),
    max_output_tokens: 220,
    reasoning: { effort: 'minimal' },
  };

  if (promptId) body.prompt = { id: promptId };

  const upstream = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
    signal,
  });

  const responseText = await upstream.text();
  if (!upstream.ok) {
    console.error(`[api/public/chat] openai error status=${upstream.status} body=${responseText.slice(0, 500)}`);
    throw new Error('openai_upstream_error');
  }

  let parsed: unknown = null;
  try {
    parsed = JSON.parse(responseText);
  } catch {
    parsed = null;
  }

  if (!parsed || typeof parsed !== 'object') return '';

  const topLevel = (parsed as { output_text?: unknown }).output_text;
  if (typeof topLevel === 'string' && topLevel.trim()) return topLevel.trim();

  const output = (parsed as { output?: unknown }).output;
  if (!Array.isArray(output)) return '';

  const parts: string[] = [];
  for (const item of output) {
    if (!item || typeof item !== 'object') continue;
    const content = (item as { content?: unknown }).content;
    if (!Array.isArray(content)) continue;

    for (const piece of content) {
      if (!piece || typeof piece !== 'object') continue;
      const text = (piece as { text?: unknown }).text;
      if (typeof text === 'string' && text.trim()) parts.push(text.trim());
    }
  }

  return parts.join(' ').trim();
}

function makeJson(body: Record<string, unknown>, status: number, setCookie?: string) {
  const headers = new Headers({
    'content-type': 'application/json; charset=utf-8',
  });
  if (setCookie) headers.append('set-cookie', setCookie);
  return new Response(JSON.stringify(body), { status, headers });
}

export async function POST(req: NextRequest) {
  let payload: ChatPayload;
  try {
    payload = (await req.json()) as ChatPayload;
  } catch {
    return makeJson({ message: truncateToTwoSentences('Geçersiz istek gövdesi. Lütfen tekrar dene.') }, 400);
  }

  const identity = resolveIdentity(req);
  const currentCount = usageStore.get(identity.key) ?? 0;

  if (currentCount >= identity.limit) {
    const message = identity.authenticated
      ? 'Mesaj limitin doldu. Daha sonra tekrar dene.'
      : 'Anonim mesaj limitin doldu. Devam etmek için kayıt olun.';

    return makeJson(
      {
        message: truncateToTwoSentences(message),
        code: 'USAGE_LIMIT_REACHED',
      },
      429,
      identity.setAnonCookie || undefined,
    );
  }

  const messages = extractMessages(payload);
  const userText = getLatestUserMessage(messages);
  if (!userText) {
    return makeJson({ message: truncateToTwoSentences('Mesaj bulunamadı. Lütfen sorunuzu tekrar yazın.') }, 400, identity.setAnonCookie || undefined);
  }

  usageStore.set(identity.key, currentCount + 1);
  const remaining = Math.max(0, identity.limit - (currentCount + 1));

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const encoder = new TextEncoder();
      let closed = false;

      const write = (chunk: string) => {
        if (!closed) controller.enqueue(encoder.encode(chunk));
      };

      const close = () => {
        if (closed) return;
        closed = true;
        controller.close();
      };

      const fail = (message: string) => {
        const safe = truncateToTwoSentences(message);
        write(`event: error\ndata: ${JSON.stringify({ message: safe })}\n\n`);
        write('event: done\ndata: {"ok":false}\n\n');
        close();
      };

      write('retry: 15000\n\n');
      write(`event: meta\ndata: ${JSON.stringify({ remaining })}\n\n`);

      const heartbeat = setInterval(() => write(': heartbeat\n\n'), 15000);
      const cleanup = () => {
        clearInterval(heartbeat);
        close();
      };

      req.signal.addEventListener('abort', cleanup, { once: true });

      (async () => {
        try {
          let responseText = '';

          if (!isRealEstateTopic(userText)) {
            responseText = truncateToTwoSentences('Bu konuda yardımcı olamam. Emlak satışı veya kiralama için mülk türü ve konumu paylaşır mısın?');
          } else {
            write(`event: status\ndata: ${JSON.stringify({ text: 'Düşünüyor...' })}\n\n`);
            const upstreamText = await fetchOpenAI(messages, req.signal);
            responseText = normalizeTwoSentenceReply(upstreamText, userText);
          }

          for (const chunk of chunkText(responseText)) {
            if (req.signal.aborted) {
              cleanup();
              return;
            }
            write(`event: delta\ndata: ${JSON.stringify({ text: `${chunk} ` })}\n\n`);
            await delay(34);
          }

          write('event: done\ndata: {"ok":true}\n\n');
          cleanup();
        } catch (err) {
          if ((err as { name?: string })?.name === 'AbortError') {
            cleanup();
            return;
          }
          console.error('[api/public/chat] failed', err);
          fail('Yanıt alınamadı. Lütfen tekrar dene.');
        }
      })();
    },
  });

  const headers = new Headers({
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-cache, no-transform',
    connection: 'keep-alive',
    'x-accel-buffering': 'no',
    'x-guest-remaining': String(remaining),
  });
  if (identity.setAnonCookie) headers.append('set-cookie', identity.setAnonCookie);

  return new Response(stream, { status: 201, headers });
}
