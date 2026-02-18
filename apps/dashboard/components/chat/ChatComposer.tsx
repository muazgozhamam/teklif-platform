import React, { useEffect, useRef, useState } from "react";
import SuggestionsOverlay from "./SuggestionsOverlay";
import { useAutosizeTextarea } from "@/hooks/useAutosizeTextarea";

type ChatComposerProps = {
  value: string;
  disabled: boolean;
  isStreaming: boolean;
  blocked?: boolean;
  suggestionActive: boolean;
  suggestionText: string;
  cursorVisible: boolean;
  onChange: (value: string) => void;
  onSend: () => void;
  onStop: () => void;
  onFocusInteraction: () => void;
  onBlurInteraction?: () => void;
};

export default function ChatComposer({
  value,
  disabled,
  isStreaming,
  blocked = false,
  suggestionActive,
  suggestionText,
  cursorVisible,
  onChange,
  onSend,
  onStop,
  onFocusInteraction,
  onBlurInteraction,
}: ChatComposerProps) {
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const recognitionRef = useRef<any>(null);
  const dictationBaseRef = useRef("");
  const [isDictating, setIsDictating] = useState(false);
  const [dictationSupported, setDictationSupported] = useState(false);
  useAutosizeTextarea({ ref: textareaRef, value });

  const canSend = !disabled && !blocked && value.trim().length > 0;

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key !== "Enter") return;
    if (e.shiftKey) return;
    if (!canSend) return;
    e.preventDefault();
    onSend();
  };

  function getRecognizerConstructor(): any | null {
    if (typeof window === "undefined") return null;
    return window.SpeechRecognition || window.webkitSpeechRecognition || null;
  }

  useEffect(() => {
    const Recognition = getRecognizerConstructor();
    if (!Recognition) return;

    const recognition = new Recognition();
    recognition.lang = "tr-TR";
    recognition.continuous = true;
    recognition.interimResults = true;

    recognition.onresult = (event: any) => {
      let transcript = "";
      const resultIndex = typeof event?.resultIndex === "number" ? event.resultIndex : 0;
      const results = event?.results ?? [];
      for (let i = resultIndex; i < results.length; i += 1) {
        transcript += results[i]?.[0]?.transcript || "";
      }
      if (transcript.trim()) {
        onChange(`${dictationBaseRef.current} ${transcript}`.replace(/\s+/g, " ").trimStart());
      }
    };

    recognition.onend = () => {
      setIsDictating(false);
    };

    recognitionRef.current = recognition;
    setDictationSupported(true);

    return () => {
      recognition.stop?.();
      recognitionRef.current = null;
    };
  }, []);

  function toggleDictation() {
    const recognition = recognitionRef.current;
    if (!recognition) return;
    if (isDictating) {
      recognition.stop();
      setIsDictating(false);
      return;
    }
    dictationBaseRef.current = value;
    recognition.start();
    setIsDictating(true);
  }

  return (
    <div
      className="rounded-[32px] border p-3"
      style={{
        borderColor: "var(--color-border)",
        background: "var(--color-composer)",
        boxShadow: "var(--shadow-lg)",
      }}
    >
      <div className="flex min-w-0 items-center gap-2">
        <div className="relative w-0 min-w-0 flex-1">
          <textarea
            id="landing-prompt-input"
            ref={textareaRef}
            value={value}
            onChange={(e) => onChange(e.target.value)}
            onKeyDown={handleKeyDown}
            onFocus={onFocusInteraction}
            onPointerDown={onFocusInteraction}
            onBlur={onBlurInteraction}
            placeholder=""
            disabled={disabled}
            rows={1}
            className="max-h-44 min-h-[48px] w-full min-w-0 resize-none rounded-full bg-transparent px-4 py-3 text-sm outline-none focus:outline-none focus:ring-0 focus-visible:ring-0 disabled:opacity-70"
            aria-label="Mesajını yaz"
          />
          <SuggestionsOverlay text={suggestionText} cursorVisible={cursorVisible} active={suggestionActive} />
        </div>

        <button
          type="button"
          onClick={toggleDictation}
          aria-label={isDictating ? "Dikteyi durdur" : "Dikteyi başlat"}
          disabled={!dictationSupported}
          title={dictationSupported ? "Dikte" : "Tarayıcı dikte desteklemiyor"}
          className="shrink-0 rounded-full border px-3 py-2 text-sm disabled:opacity-50"
          style={{
            borderColor: "var(--color-border)",
            color: isDictating ? "var(--color-primary-600)" : "var(--color-text-secondary)",
            background: isDictating ? "color-mix(in oklab, var(--color-primary-600) 12%, var(--color-surface))" : "transparent",
          }}
        >
          <span className="inline-flex items-center gap-1">
            <MicIcon className="h-4 w-4" />
            <span>Dikte</span>
          </span>
        </button>

        {isStreaming ? (
          <button
            type="button"
            onClick={onStop}
            aria-label="Yanıtı durdur"
            className="shrink-0 rounded-full px-4 py-2 text-sm font-medium text-white"
            style={{ background: "#2f2f2f" }}
          >
            ■
          </button>
        ) : (
          <button
            type="button"
            onClick={onSend}
            disabled={!canSend}
            aria-label="Mesajı gönder"
            className="shrink-0 rounded-full px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
            style={{ background: "#2f2f2f" }}
          >
            ↑
          </button>
        )}
      </div>
    </div>
  );
}

function MicIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className={className} fill="none" stroke="currentColor" strokeWidth="1.8">
      <path d="M12 15a4 4 0 0 0 4-4V7a4 4 0 0 0-8 0v4a4 4 0 0 0 4 4Z" />
      <path d="M19 11a7 7 0 1 1-14 0" />
      <path d="M12 18v4" />
    </svg>
  );
}
