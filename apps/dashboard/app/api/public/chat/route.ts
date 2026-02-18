import { NextRequest } from 'next/server';
import { truncateToTwoSentences } from '@/lib/chat/sentenceLimit';
import {
  buildClarifyQuestion,
  classifyIntentTr,
  openingFormMessage,
  reminderToCompleteForm,
  resolveFormIntent,
} from '@/lib/chat/funnelPolicy';
import {
  getConversationState,
  resolveIdentity,
  saveConversationState,
  type ChatIntent,
} from '@/lib/chat/funnelState';
import { shouldTriggerForm } from '@/lib/chat/limitPolicy';

export const runtime = 'nodejs';

type ChatPayload = {
  message?: unknown;
  history?: unknown;
  messages?: unknown;
};

type UpstreamMessage = { role: 'user' | 'assistant'; content: string };

type FormType = 'CONSULTANT_FORM' | 'HUNTER_FORM' | 'OWNER_FORM' | 'INVESTOR_FORM';

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

function toFormType(intent: ChatIntent): FormType {
  if (intent === 'CONSULTANT_APPLY') return 'CONSULTANT_FORM';
  if (intent === 'HUNTER_APPLY') return 'HUNTER_FORM';
  if (intent === 'INVESTOR') return 'INVESTOR_FORM';
  return 'OWNER_FORM';
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

function toSse(event: string, payload: Record<string, unknown>) {
  return `event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`;
}

function makeJson(body: Record<string, unknown>, status: number, setCookie?: string) {
  const headers = new Headers({ 'content-type': 'application/json; charset=utf-8' });
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
  const state = getConversationState(identity);

  const messages = extractMessages(payload);
  const userText = getLatestUserMessage(messages);
  if (!userText) {
    return makeJson({ message: truncateToTwoSentences('Mesaj bulunamadı. Lütfen sorunuzu tekrar yazın.') }, 400, identity.setAnonCookie || undefined);
  }

  state.messageCount += 1;

  const classified = classifyIntentTr(userText);
  if (classified.confidence >= state.intentConfidence || !state.intent) {
    state.intent = classified.intent;
    state.intentConfidence = classified.confidence;
  }

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

      const heartbeat = setInterval(() => write(': heartbeat\n\n'), 15000);
      const cleanup = () => {
        clearInterval(heartbeat);
        close();
      };

      req.signal.addEventListener('abort', cleanup, { once: true });

      (async () => {
        try {
          write('retry: 15000\n\n');

          const enforcedIntent = resolveFormIntent(state.intent ?? 'GENERIC');
          const triggerForm = shouldTriggerForm({
            authenticated: identity.authenticated,
            messageCount: state.messageCount,
            confidence: state.intentConfidence,
          });

          if (state.formStatus === 'SHOWN') {
            state.step = 'FORM_TRIGGERED';
            const msg = reminderToCompleteForm();
            for (const chunk of chunkText(msg)) {
              write(toSse('delta', { text: `${chunk} ` }));
              await delay(30);
            }
            write(toSse('form', { intent: enforcedIntent, formType: toFormType(enforcedIntent), required: true }));
            write('event: done\ndata: {"ok":true}\n\n');
            saveConversationState(identity, state);
            cleanup();
            return;
          }

          if (triggerForm) {
            state.step = 'FORM_TRIGGERED';
            state.formStatus = 'SHOWN';
            state.intent = enforcedIntent;
            const msg = openingFormMessage(enforcedIntent);
            for (const chunk of chunkText(msg)) {
              write(toSse('delta', { text: `${chunk} ` }));
              await delay(30);
            }
            write(toSse('form', { intent: enforcedIntent, formType: toFormType(enforcedIntent), required: true }));
            write('event: done\ndata: {"ok":true}\n\n');
            saveConversationState(identity, state);
            cleanup();
            return;
          }

          state.step = state.messageCount <= 1 ? 'DISCOVERY' : 'QUALIFICATION';
          const msg = buildClarifyQuestion(state.intent ?? 'GENERIC');
          for (const chunk of chunkText(msg)) {
            write(toSse('delta', { text: `${chunk} ` }));
            await delay(30);
          }

          write('event: done\ndata: {"ok":true}\n\n');
          saveConversationState(identity, state);
          cleanup();
        } catch (err) {
          console.error('[api/public/chat] failed', err);
          const safe = truncateToTwoSentences('Yanıt alınamadı. Lütfen tekrar deneyin.');
          write(toSse('error', { message: safe }));
          write('event: done\ndata: {"ok":false}\n\n');
          cleanup();
        }
      })();
    },
  });

  const headers = new Headers({
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-cache, no-transform',
    connection: 'keep-alive',
    'x-accel-buffering': 'no',
  });
  if (identity.setAnonCookie) headers.append('set-cookie', identity.setAnonCookie);

  return new Response(stream, { status: 201, headers });
}
