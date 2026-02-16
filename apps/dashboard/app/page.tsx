"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import LandingShell from "@/components/landing/LandingShell";
import PromptBar from "@/components/landing/PromptBar";
import SuggestionCard from "@/components/landing/SuggestionCard";
import LandingHeader from "@/components/landing/LandingHeader";

type Role = "assistant" | "user" | "system";
type Message = { id: string; role: Role; text: string };

export default function PublicChatPage() {
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

  const listRef = useRef<HTMLDivElement | null>(null);
  const composerRef = useRef<HTMLTextAreaElement | HTMLInputElement | null>(null);

  const placeholder = useMemo(
    () => "Lütfen bize ne istediğini söyle. Örn: 3+1 dairemin fiyatını öğrenmek istiyorum.",
    [],
  );

  const isCenteredComposer = messages.length <= 1;

  useEffect(() => {
    const el = listRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [messages, isStreaming]);

  function addMessage(role: Role, text: string) {
    const id = `m_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    setMessages((prev) => [...prev, { id, role, text }]);
    return id;
  }

  function setAssistantText(messageId: string, text: string) {
    setMessages((prev) =>
      prev.map((m) => (m.id === messageId ? { ...m, text } : m)),
    );
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
    setShowSuggestionCard(false);
    addMessage("user", text);
    const assistantId = addMessage("assistant", "");

    setIsStreaming(true);
    try {
      const res = await fetch("/api/public/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: text, history }),
      });

      if (!res.ok) {
        const bodyText = await res.text().catch(() => "");
        throw new Error(`Chat failed: ${res.status} ${bodyText}`);
      }

      const payload = (await res.json()) as { text?: string };
      const reply = (payload?.text || "").trim();

      if (!reply) {
        setAssistantText(assistantId, "Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?");
        setLastError("Yanıt üretilemedi.");
        return;
      }

      setAssistantText(assistantId, reply);
      setLastError(null);
    } catch {
      setAssistantText(assistantId, "Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?");
      setLastError("Bağlantı koptu. Lütfen tekrar dene.");
    } finally {
      setIsStreaming(false);
    }
  }

  return (
    <LandingShell footer="SatDedi Asistanı size destek olur; önemli kararlar öncesinde teyit etmenizi öneririz.">
      <LandingHeader />

      {isCenteredComposer ? (
        <section className="flex flex-1 flex-col items-center justify-center">
          <h1 className="mb-6 text-center text-3xl font-semibold tracking-tight md:text-5xl">
            Nasıl yardımcı olabilirim?
          </h1>

          <div className="w-full">
            <PromptBar
              phase="collect_intent"
              input={input}
              disabled={isStreaming}
              placeholder={placeholder}
              onSend={onSend}
              onInputChange={(value) => setInput(value)}
              isPhoneValid
              inputRef={composerRef}
            />

            {showSuggestionCard ? (
              <SuggestionCard onTryNow={() => composerRef.current?.focus()} onClose={() => setShowSuggestionCard(false)} />
            ) : null}
          </div>
        </section>
      ) : (
        <>
          <section
            ref={listRef}
            className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 overflow-y-auto pb-40 pt-6"
          >
            {messages.map((m) => (
              <div key={m.id} className={`flex w-full ${m.role === "user" ? "justify-end" : "justify-start"}`}>
                <div
                  className={[
                    "max-w-[88%] whitespace-pre-wrap rounded-3xl px-4 py-3 text-[15px] leading-7",
                    m.role === "user" ? "text-white" : "",
                  ].join(" ")}
                  style={
                    m.role === "user"
                      ? { background: "#2f2f2f" }
                      : m.role === "system"
                        ? {
                            background: "rgba(220,38,38,0.08)",
                            border: "1px solid rgba(220,38,38,0.25)",
                            color: "var(--color-danger-600)",
                          }
                        : { color: "var(--color-text-primary)" }
                  }
                >
                  {m.text}
                </div>
              </div>
            ))}

            {isStreaming ? (
              <div className="flex w-full justify-start">
                <div
                  className="max-w-[88%] rounded-3xl px-4 py-3 text-[15px]"
                  style={{ color: "var(--color-text-muted)" }}
                >
                  Yazıyor...
                </div>
              </div>
            ) : null}

            {lastError ? (
              <div
                className="mx-auto w-full max-w-2xl rounded-2xl border px-4 py-3 text-xs"
                style={{
                  borderColor: "rgba(220,38,38,0.3)",
                  background: "rgba(220,38,38,0.08)",
                  color: "var(--color-danger-600)",
                }}
              >
                {lastError}
              </div>
            ) : null}
          </section>

          <div className="fixed bottom-0 left-0 right-0 z-20 px-3 pb-4 pt-2 md:px-6">
            <div className="mx-auto w-full max-w-3xl">
              <PromptBar
                phase="collect_intent"
                input={input}
                disabled={isStreaming}
                placeholder={placeholder}
                onSend={onSend}
                onInputChange={(value) => setInput(value)}
                isPhoneValid
                inputRef={composerRef}
              />
            </div>
          </div>
        </>
      )}
    </LandingShell>
  );
}
