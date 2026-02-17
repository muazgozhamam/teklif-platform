import React, { useRef } from "react";
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
  useAutosizeTextarea({ ref: textareaRef, value });

  const canSend = !disabled && !blocked && value.trim().length > 0;

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key !== "Enter") return;
    if (e.shiftKey) return;
    if (!canSend) return;
    e.preventDefault();
    onSend();
  };

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
          aria-label="Dikte (yakında)"
          className="shrink-0 rounded-full border px-3 py-2 text-sm"
          style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
        >
          <span className="inline-flex items-center gap-1">
            <span aria-hidden="true">🎤</span>
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
