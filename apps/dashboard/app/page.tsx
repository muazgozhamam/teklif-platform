'use client';

import React, { useMemo, useRef, useState } from 'react';
import LandingShell from '@/components/landing/LandingShell';
import CenterColumn from '@/components/landing/CenterColumn';
import SuggestionCard from '@/components/landing/SuggestionCard';
import StickyHeader from '@/components/chat/StickyHeader';
import ChatComposer from '@/components/chat/ChatComposer';
import MessageList from '@/components/chat/MessageList';
import ScrollToBottomButton from '@/components/chat/ScrollToBottomButton';
import { useRotatingSuggestions } from '@/hooks/useRotatingSuggestions';
import { useChatScroll } from '@/hooks/useChatScroll';

type Role = 'assistant' | 'user' | 'system';
type FormIntent = 'CONSULTANT_APPLY' | 'HUNTER_APPLY' | 'OWNER_SELL' | 'OWNER_RENT' | 'INVESTOR' | 'GENERIC';

type Message = {
  id: string;
  role: Role;
  text: string;
  kind?: 'text' | 'form';
  formIntent?: FormIntent;
  formSubmitted?: boolean;
};

export default function PublicChatPage() {
  const helperDisclaimer = 'SatDedi Asistanı size destek olur; önemli kararlar öncesinde teyit etmenizi öneririz.';

  const [phase, setPhase] = useState<'prechat' | 'chat'>('prechat');
  const [hasStarted, setHasStarted] = useState(false);
  const [composerFocused, setComposerFocused] = useState(false);

  const [messages, setMessages] = useState<Message[]>([
    {
      id: 'welcome',
      role: 'assistant',
      text: 'Merhaba, ben SatDedi Asistanı. Seni uygun sürece almak için kısa birkaç soru soracağım.',
    },
  ]);
  const [input, setInput] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);
  const [lastError, setLastError] = useState<string | null>(null);
  const [showSuggestionCard, setShowSuggestionCard] = useState(true);
  const [formSubmittingId, setFormSubmittingId] = useState<string | null>(null);
  const activeRequestRef = useRef<AbortController | null>(null);

  const suggestionSentences = useMemo(
    () => [
      'Danışman olmak istiyorum.',
      '3+1 dairemin satışı için talep oluşturmak istiyorum.',
      "Meram'da evimi kiraya vermek istiyorum.",
      'Ticari mülkümü değerlendirmek istiyorum.',
      'Yatırım için doğru bölgeleri öğrenmek istiyorum.',
      'İş ortağı olarak sürece katılmak istiyorum.',
      'Mülküm için ilana başlamak istiyorum.',
      'Portföyümü SatDedi ile büyütmek istiyorum.',
    ],
    [],
  );

  const suggestionActive = phase === 'prechat' && !hasStarted && !composerFocused && input.trim().length === 0;
  const { text: suggestionText, cursorVisible } = useRotatingSuggestions({
    suggestions: suggestionSentences,
    active: suggestionActive,
  });

  const dependencyKey = `${messages.map((m) => `${m.id}:${m.text.length}:${m.kind || 'text'}`).join('|')}:${isStreaming ? '1' : '0'}`;
  const { containerRef, isAtBottom, showScrollDown, newBelowCount, onScroll, scrollToBottom } = useChatScroll({
    dependencyKey,
    bottomThreshold: 120,
  });

  const isCenteredComposer = phase === 'prechat';

  function addMessage(message: Omit<Message, 'id'>) {
    const id = `m_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    const next = { id, ...message };
    setMessages((prev) => [...prev, next]);
    return id;
  }

  function setAssistantText(messageId: string, text: string) {
    setMessages((prev) => prev.map((m) => (m.id === messageId ? { ...m, text } : m)));
  }

  function appendAssistantText(messageId: string, deltaText: string) {
    setMessages((prev) => prev.map((m) => (m.id === messageId ? { ...m, text: `${m.text}${deltaText}` } : m)));
  }

  function onComposerInteract() {
    setComposerFocused(true);
  }

  function onComposerBlur() {
    if (!hasStarted) setComposerFocused(false);
  }

  function stopStreaming() {
    activeRequestRef.current?.abort();
    activeRequestRef.current = null;
    setIsStreaming(false);
  }

  async function onSubmitForm(messageId: string, intent: FormIntent, data: Record<string, string>) {
    setFormSubmittingId(messageId);
    setLastError(null);

    try {
      const res = await fetch('/api/public/chat/form', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ intent, data }),
      });

      const payload = (await res.json().catch(() => ({}))) as { ok?: boolean; message?: string };
      if (!res.ok || !payload?.ok) {
        throw new Error(payload?.message || 'Form gönderilemedi.');
      }

      setMessages((prev) => prev.map((m) => (m.id === messageId ? { ...m, formSubmitted: true } : m)));
      addMessage({ role: 'assistant', text: payload.message || 'Teşekkürler, talebiniz alındı.', kind: 'text' });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Form gönderimi sırasında hata oluştu.';
      setLastError(msg);
    } finally {
      setFormSubmittingId(null);
    }
  }

  async function onSend() {
    const text = input.trim();
    if (!text || isStreaming) return;

    const history = messages
      .filter((m) => m.kind !== 'form' && (m.role === 'assistant' || m.role === 'user') && m.text.trim().length > 0)
      .slice(-12)
      .map((m) => ({ role: m.role, content: m.text }));

    setInput('');
    setLastError(null);
    setComposerFocused(false);

    if (!hasStarted) {
      setHasStarted(true);
      setPhase('chat');
      setShowSuggestionCard(false);
    }

    addMessage({ role: 'user', text, kind: 'text' });
    const assistantId = addMessage({ role: 'assistant', text: '', kind: 'text' });
    setIsStreaming(true);

    const controller = new AbortController();
    activeRequestRef.current = controller;

    try {
      const res = await fetch('/api/public/chat', {
        method: 'POST',
        headers: {
          Accept: 'text/event-stream, application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message: text, history }),
        signal: controller.signal,
      });

      if (!res.ok) {
        const bodyText = await res.text().catch(() => '');
        throw new Error(`Chat failed: ${res.status} ${bodyText}`);
      }

      const contentType = (res.headers.get('content-type') || '').toLowerCase();
      if (!contentType.includes('text/event-stream')) {
        const payload = (await res.json()) as { text?: string; message?: string };
        const reply = (payload?.text || payload?.message || '').trim();
        if (!reply) {
          setAssistantText(assistantId, 'Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?');
          setLastError('Yanıt üretilemedi.');
          return;
        }
        setAssistantText(assistantId, reply);
        return;
      }

      const reader = res.body?.getReader();
      if (!reader) throw new Error('No response stream');

      const decoder = new TextDecoder();
      let buffer = '';
      let sawDelta = false;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const blocks = buffer.split('\n\n');
        buffer = blocks.pop() ?? '';

        for (const rawBlock of blocks) {
          const block = rawBlock.trim();
          if (!block) continue;

          const lines = block.split('\n');
          let eventName = 'message';
          const dataLines: string[] = [];

          for (const line of lines) {
            if (line.startsWith(':')) continue;
            if (line.startsWith('event:')) {
              eventName = line.slice(6).trim();
              continue;
            }
            if (line.startsWith('data:')) dataLines.push(line.slice(5).trim());
          }

          if (!dataLines.length) continue;

          let payload: { text?: string; message?: string; intent?: FormIntent } | null = null;
          try {
            payload = JSON.parse(dataLines.join('\n'));
          } catch {
            payload = null;
          }

          if (eventName === 'delta' && payload?.text) {
            sawDelta = true;
            appendAssistantText(assistantId, payload.text);
            continue;
          }

          if (eventName === 'form' && payload?.intent) {
            setMessages((prev) => {
              const alreadyOpen = prev.some((m) => m.kind === 'form' && m.formIntent === payload!.intent && !m.formSubmitted);
              if (alreadyOpen) return prev;
              const id = `form_${Date.now()}_${Math.random().toString(16).slice(2)}`;
              return [...prev, { id, role: 'assistant', text: '', kind: 'form', formIntent: payload.intent, formSubmitted: false }];
            });
            continue;
          }

          if (eventName === 'error') {
            setLastError(payload?.message || 'Bağlantı koptu. Lütfen tekrar dene.');
          }
        }
      }

      if (!sawDelta) {
        setAssistantText(assistantId, 'Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?');
        setLastError('Yanıt üretilemedi.');
      }
    } catch (err) {
      if ((err as { name?: string })?.name === 'AbortError') {
        setLastError(null);
        return;
      }
      console.error('[chat-ui] stream failed', err);
      setAssistantText(assistantId, 'Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?');
      setLastError('Bağlantı koptu. Lütfen tekrar dene.');
    } finally {
      activeRequestRef.current = null;
      setIsStreaming(false);
    }
  }

  return (
    <LandingShell>
      <StickyHeader />

      {isCenteredComposer ? (
        <section className="flex flex-1 flex-col items-center justify-center">
          <CenterColumn className="flex flex-col gap-5">
            <h1 className="text-center text-3xl font-semibold tracking-tight md:text-5xl">Nasıl yardımcı olabilirim?</h1>

            <ChatComposer
              value={input}
              disabled={false}
              isStreaming={isStreaming}
              suggestionActive={suggestionActive}
              suggestionText={suggestionText}
              cursorVisible={cursorVisible}
              onChange={setInput}
              onSend={onSend}
              onStop={stopStreaming}
              onFocusInteraction={onComposerInteract}
              onBlurInteraction={onComposerBlur}
            />

            <p className="mt-2 text-center text-xs" style={{ color: 'var(--color-text-muted)' }}>
              {helperDisclaimer}
            </p>

            {showSuggestionCard ? (
              <SuggestionCard
                onTryNow={() => {
                  setComposerFocused(true);
                  const el = document.getElementById('landing-prompt-input') as HTMLTextAreaElement | null;
                  el?.focus();
                }}
                onClose={() => setShowSuggestionCard(false)}
              />
            ) : null}
          </CenterColumn>
        </section>
      ) : (
        <>
          <MessageList
            messages={messages}
            isStreaming={isStreaming}
            lastError={lastError}
            containerRef={containerRef}
            onScroll={onScroll}
            onSubmitForm={onSubmitForm}
            formSubmittingId={formSubmittingId}
          />

          <ScrollToBottomButton visible={showScrollDown} count={newBelowCount} onClick={() => scrollToBottom(true)} />

          <div className="fixed bottom-0 left-0 right-0 z-20 px-3 pb-4 pt-2 md:px-6" style={{ paddingBottom: 'max(1rem, env(safe-area-inset-bottom))' }}>
            <div className="mx-auto w-full max-w-3xl">
              <ChatComposer
                value={input}
                disabled={false}
                isStreaming={isStreaming}
                suggestionActive={false}
                suggestionText=""
                cursorVisible={false}
                onChange={setInput}
                onSend={onSend}
                onStop={stopStreaming}
                onFocusInteraction={onComposerInteract}
                onBlurInteraction={onComposerBlur}
              />
              <p className="mt-2 text-center text-xs" style={{ color: 'var(--color-text-muted)' }}>
                {helperDisclaimer}
              </p>
            </div>
          </div>
        </>
      )}

      <span className="sr-only" aria-hidden="true">
        phase:{phase}; hasStarted:{String(hasStarted)}; isAtBottom:{String(isAtBottom)}; isStreaming:{String(isStreaming)};
        showScrollDown:{String(showScrollDown)}; suggestionActive:{String(suggestionActive)}
      </span>
    </LandingShell>
  );
}
