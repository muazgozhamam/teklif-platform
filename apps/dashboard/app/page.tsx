"use client";

import React, { useMemo, useState } from "react";
import LandingShell from "@/components/landing/LandingShell";
import SuggestionCard from "@/components/landing/SuggestionCard";
import StickyHeader from "@/components/chat/StickyHeader";
import ChatComposer from "@/components/chat/ChatComposer";
import MessageList from "@/components/chat/MessageList";
import ScrollToBottomButton from "@/components/chat/ScrollToBottomButton";
import { useRotatingSuggestions } from "@/hooks/useRotatingSuggestions";
import { useChatScroll } from "@/hooks/useChatScroll";

type Role = "assistant" | "user" | "system";
type Message = { id: string; role: Role; text: string };

function resolvePublicApiBase() {
  const envBase = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
  if (envBase) return envBase.replace(/\/+$/, "");

  if (typeof window === "undefined") return "";
  const host = window.location.hostname;
  if (host === "stage.satdedi.com") return "https://api-stage-44dd.up.railway.app";
  if (host === "app.satdedi.com") return "https://api.satdedi.com";
  return "";
}

export default function PublicChatPage() {
  const [phase, setPhase] = useState<"prechat" | "chat">("prechat");
  const [hasStarted, setHasStarted] = useState(false);
  const [composerFocused, setComposerFocused] = useState(false);

  const [messages, setMessages] = useState<Message[]>([
    {
      id: "welcome",
      role: "assistant",
      text: "Merhaba, ben SatDedi Asistanı. Emlakla ilgili sorunu yaz, birlikte netleştirelim.",
    },
  ]);
  const [input, setInput] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const [lastError, setLastError] = useState<string | null>(null);
  const [showSuggestionCard, setShowSuggestionCard] = useState(true);

  const suggestionSentences = useMemo(
    () => [
      "Danışman olmak istiyorum.",
      "3+1 dairemin fiyatını öğrenmek istiyorum.",
      "Meram'da evimi kiraya vermek istiyorum.",
      "Ticari mülkümü değerlendirmek istiyorum.",
      "Evimi hızlı satmak için nasıl ilerlemeliyim?",
      "Arsam için doğru satış planı istiyorum.",
      "İş ortağı olarak sürece katılmak istiyorum.",
      "Mülküm için ilan sürecini başlatmak istiyorum.",
      "Doğru alıcıya daha hızlı ulaşmak istiyorum.",
      "SatDedi ile satış sürecini başlatalım.",
    ],
    [],
  );

  // UX rule: suggestions run only pre-chat, only when input is not focused and empty.
  const suggestionActive = phase === "prechat" && !hasStarted && !composerFocused && input.trim().length === 0;
  const { text: suggestionText, cursorVisible } = useRotatingSuggestions({
    suggestions: suggestionSentences,
    active: suggestionActive,
  });

  const dependencyKey = `${messages.map((m) => `${m.id}:${m.text.length}`).join("|")}:${isStreaming ? "1" : "0"}`;
  const {
    containerRef,
    isAtBottom,
    showScrollDown,
    newBelowCount,
    onScroll,
    scrollToBottom,
  } = useChatScroll({ dependencyKey });

  const isCenteredComposer = phase === "prechat";

  function addMessage(role: Role, text: string) {
    const id = `m_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    setMessages((prev) => [...prev, { id, role, text }]);
    return id;
  }

  function setAssistantText(messageId: string, text: string) {
    setMessages((prev) => prev.map((m) => (m.id === messageId ? { ...m, text } : m)));
  }

  function appendAssistantText(messageId: string, deltaText: string) {
    setMessages((prev) => prev.map((m) => (m.id === messageId ? { ...m, text: `${m.text}${deltaText}` } : m)));
  }

  function onComposerInteract() {
    // UX rule: focus/click hides suggestion text immediately, but does not start chat.
    setComposerFocused(true);
  }

  function onComposerBlur() {
    if (!hasStarted) setComposerFocused(false);
  }

  async function onSend() {
    const text = input.trim();
    if (!text || isStreaming) return;

    const history = messages
      .filter((m) => (m.role === "assistant" || m.role === "user") && m.text.trim().length > 0)
      .slice(-12)
      .map((m) => ({ role: m.role, content: m.text }));

    setInput("");
    setLastError(null);
    setComposerFocused(false);

    // UX rule: chat starts only when first message is sent.
    if (!hasStarted) {
      setHasStarted(true);
      setPhase("chat");
      setShowSuggestionCard(false);
    }

    addMessage("user", text);
    const assistantId = addMessage("assistant", "");
    setIsStreaming(true);

    try {
      const apiBase = resolvePublicApiBase();
      const endpoint = apiBase ? `${apiBase}/public/chat/stream` : "/api/public/chat";

      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Accept: "text/event-stream, application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message: text, history }),
      });

      if (!res.ok) {
        const bodyText = await res.text().catch(() => "");
        throw new Error(`Chat failed: ${res.status} ${bodyText}`);
      }

      const contentType = (res.headers.get("content-type") || "").toLowerCase();

      if (!contentType.includes("text/event-stream")) {
        const payload = (await res.json()) as { text?: string };
        const reply = (payload?.text || "").trim();
        if (!reply) {
          setAssistantText(assistantId, "Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?");
          setLastError("Yanıt üretilemedi.");
          return;
        }
        setAssistantText(assistantId, reply);
        setLastError(null);
        return;
      }

      const reader = res.body?.getReader();
      if (!reader) throw new Error("No response stream");

      const decoder = new TextDecoder();
      let buffer = "";
      let sawDelta = false;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const blocks = buffer.split("\n\n");
        buffer = blocks.pop() ?? "";

        for (const rawBlock of blocks) {
          const block = rawBlock.trim();
          if (!block) continue;

          const lines = block.split("\n");
          let eventName = "message";
          const dataLines: string[] = [];

          for (const line of lines) {
            if (line.startsWith(":")) continue;
            if (line.startsWith("event:")) {
              eventName = line.slice(6).trim();
              continue;
            }
            if (line.startsWith("data:")) {
              dataLines.push(line.slice(5).trim());
            }
          }

          if (!dataLines.length) continue;

          let payload: { text?: string; message?: string; ok?: boolean } | null = null;
          try {
            payload = JSON.parse(dataLines.join("\n"));
          } catch {
            payload = null;
          }

          if (eventName === "delta" && payload?.text) {
            sawDelta = true;
            appendAssistantText(assistantId, payload.text);
            continue;
          }

          if (eventName === "error") {
            setLastError(payload?.message || "Bağlantı koptu. Lütfen tekrar dene.");
          }
        }
      }

      if (!sawDelta) {
        setAssistantText(assistantId, "Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?");
        setLastError("Yanıt üretilemedi.");
      } else {
        setLastError(null);
      }
    } catch (err) {
      console.error("[chat-ui] stream failed", err);
      setAssistantText(assistantId, "Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?");
      setLastError("Bağlantı koptu. Lütfen tekrar dene.");
    } finally {
      setIsStreaming(false);
    }
  }

  return (
    <LandingShell footer="SatDedi Asistanı size destek olur; önemli kararlar öncesinde teyit etmenizi öneririz.">
      <StickyHeader />

      {isCenteredComposer ? (
        <section className="flex flex-1 flex-col items-center justify-center">
          <h1 className="mb-6 text-center text-3xl font-semibold tracking-tight md:text-5xl">
            Nasıl yardımcı olabilirim?
          </h1>

          <div className="w-full">
            <ChatComposer
              value={input}
              disabled={isStreaming}
              suggestionActive={suggestionActive}
              suggestionText={suggestionText}
              cursorVisible={cursorVisible}
              onChange={setInput}
              onSend={onSend}
              onFocusInteraction={onComposerInteract}
              onBlurInteraction={onComposerBlur}
            />

            {showSuggestionCard ? (
              <SuggestionCard
                onTryNow={() => {
                  setComposerFocused(true);
                  const el = document.getElementById("landing-prompt-input") as HTMLTextAreaElement | null;
                  el?.focus();
                }}
                onClose={() => setShowSuggestionCard(false)}
              />
            ) : null}
          </div>
        </section>
      ) : (
        <>
          <MessageList
            messages={messages}
            isStreaming={isStreaming}
            lastError={lastError}
            containerRef={containerRef}
            onScroll={onScroll}
          />

          <ScrollToBottomButton visible={showScrollDown} count={newBelowCount} onClick={scrollToBottom} />

          <div className="fixed bottom-0 left-0 right-0 z-20 px-3 pb-4 pt-2 md:px-6">
            <div className="mx-auto w-full max-w-3xl">
              <ChatComposer
                value={input}
                disabled={isStreaming}
                suggestionActive={false}
                suggestionText=""
                cursorVisible={false}
                onChange={setInput}
                onSend={onSend}
                onFocusInteraction={onComposerInteract}
                onBlurInteraction={onComposerBlur}
              />
            </div>
          </div>
        </>
      )}

      {/* Explicit state exposure for UX debugging */}
      <span className="sr-only" aria-hidden="true">
        phase:{phase}; hasStarted:{String(hasStarted)}; isAtBottom:{String(isAtBottom)}; isStreaming:{String(isStreaming)};
        showScrollDown:{String(showScrollDown)}; suggestionActive:{String(suggestionActive)}
      </span>
    </LandingShell>
  );
}
