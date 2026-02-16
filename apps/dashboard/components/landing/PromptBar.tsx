import React, { useState } from "react";

type PromptBarProps = {
  phase: "collect_intent" | "wizard" | "collect_phone" | "submitting" | "done" | "error";
  input: string;
  disabled: boolean;
  placeholder: string;
  onSend: () => void;
  onInputChange: (value: string) => void;
  isPhoneValid: boolean;
  inputRef: React.RefObject<HTMLTextAreaElement | HTMLInputElement | null>;
};

export default function PromptBar({
  phase,
  input,
  disabled,
  placeholder,
  onSend,
  onInputChange,
  isPhoneValid,
  inputRef,
}: PromptBarProps) {
  const isPhone = phase === "collect_phone";
  const [isPromptFocused, setIsPromptFocused] = useState(false);
  const showPromptMarquee = !isPhone && !isPromptFocused && input.trim().length === 0;
  const canSend = !disabled && (isPhone ? isPhoneValid : !!input.trim());

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
        {isPhone ? (
          <input
            ref={inputRef as React.RefObject<HTMLInputElement>}
            type="tel"
            inputMode="numeric"
            autoComplete="tel"
            value={input}
            onChange={(e) => onInputChange(e.target.value)}
            placeholder="05xx xxx xx xx"
            className="h-12 w-0 min-w-0 flex-1 rounded-full bg-transparent px-4 text-sm outline-none focus:outline-none focus:ring-0 focus-visible:ring-0"
            aria-label="Telefon numarası"
          />
        ) : (
          <div className="relative w-0 min-w-0 flex-1">
            <textarea
              id="landing-prompt-input"
              ref={inputRef as React.RefObject<HTMLTextAreaElement>}
              value={input}
              onChange={(e) => onInputChange(e.target.value)}
              onFocus={() => setIsPromptFocused(true)}
              onBlur={() => setIsPromptFocused(false)}
              placeholder={placeholder}
              disabled={disabled}
              rows={1}
              className="mobile-marquee-input max-h-40 min-h-[48px] w-full min-w-0 resize-none rounded-full bg-transparent px-4 py-3 text-sm outline-none focus:outline-none focus:ring-0 focus-visible:ring-0 disabled:opacity-70"
              aria-label="Mesajını yaz"
            />
            {showPromptMarquee ? (
              <div
                aria-hidden="true"
                className="mobile-marquee pointer-events-none absolute inset-y-0 left-4 right-4 flex max-w-full items-center overflow-hidden whitespace-nowrap text-sm sm:hidden"
                style={{ color: "var(--color-text-muted)" }}
              >
                <span className="mobile-marquee-text inline-block whitespace-nowrap">{placeholder}</span>
              </div>
            ) : null}
          </div>
        )}

        <button
          type="button"
          aria-label="Ses ile giriş (yakında)"
          className="shrink-0 rounded-full border px-3 py-2 text-sm"
          style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
        >
          Ses
        </button>

        <button
          type="button"
          onClick={onSend}
          disabled={!canSend}
          aria-label="Mesajı gönder"
          className="shrink-0 rounded-full px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
          style={{ background: "#2f2f2f" }}
        >
          Gönder
        </button>
      </div>
    </div>
  );
}
