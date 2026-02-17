import React, { useEffect, useMemo, useState } from "react";

type PromptBarProps = {
  phase: "collect_intent" | "wizard" | "collect_phone" | "submitting" | "done" | "error";
  input: string;
  disabled: boolean;
  placeholder: string;
  exampleText?: string;
  showExampleAsValue?: boolean;
  exampleSentences?: string[];
  onSend: () => void;
  onInputChange: (value: string) => void;
  isPhoneValid: boolean;
  inputRef: React.RefObject<HTMLTextAreaElement | HTMLInputElement | null>;
  onInteract?: () => void;
};

export default function PromptBar({
  phase,
  input,
  disabled,
  placeholder,
  exampleText,
  showExampleAsValue = false,
  exampleSentences,
  onSend,
  onInputChange,
  isPhoneValid,
  inputRef,
  onInteract,
}: PromptBarProps) {
  const isPhone = phase === "collect_phone";
  const rotatingExamples = useMemo(
    () =>
      exampleSentences && exampleSentences.length > 0
        ? exampleSentences
        : [exampleText || "Danışman olmak istiyorum."],
    [exampleSentences, exampleText],
  );
  const [typedText, setTypedText] = useState("");
  const [exampleIndex, setExampleIndex] = useState(0);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showCursor, setShowCursor] = useState(true);
  const canSend = !disabled && (isPhone ? isPhoneValid : !!input.trim());
  const handleEnterToSend = (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    if (e.key !== "Enter") return;
    if (e.shiftKey) return;
    if (!canSend) return;
    e.preventDefault();
    onSend();
  };

  const handleTextFocusOrClick = () => {
    onInteract?.();
    if (showExampleAsValue) onInputChange("");
  };

  useEffect(() => {
    if (!showExampleAsValue) {
      if (typedText) setTypedText("");
      if (isDeleting) setIsDeleting(false);
      return;
    }

    const current = rotatingExamples[exampleIndex] || "";
    let delay = 55;

    if (!isDeleting && typedText.length < current.length) delay = 42;
    else if (!isDeleting && typedText.length === current.length) delay = 1400;
    else if (isDeleting && typedText.length > 0) delay = 26;
    else delay = 260;

    const timer = window.setTimeout(() => {
      if (!isDeleting && typedText.length < current.length) {
        setTypedText(current.slice(0, typedText.length + 1));
        return;
      }

      if (!isDeleting && typedText.length === current.length) {
        setIsDeleting(true);
        return;
      }

      if (isDeleting && typedText.length > 0) {
        setTypedText(current.slice(0, typedText.length - 1));
        return;
      }

      setIsDeleting(false);
      setExampleIndex((prev) => (prev + 1) % rotatingExamples.length);
    }, delay);

    return () => window.clearTimeout(timer);
  }, [exampleIndex, isDeleting, rotatingExamples, showExampleAsValue, typedText]);

  useEffect(() => {
    if (!showExampleAsValue) {
      setShowCursor(false);
      return;
    }
    setShowCursor(true);
    const cursorTimer = window.setInterval(() => {
      setShowCursor((prev) => !prev);
    }, 480);
    return () => window.clearInterval(cursorTimer);
  }, [showExampleAsValue]);

  const displayValue = showExampleAsValue
    ? `${typedText}${showCursor ? "|" : ""}`
    : input;

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
            onKeyDown={handleEnterToSend}
            onFocus={onInteract}
            onClick={onInteract}
            placeholder=""
            className="h-12 w-0 min-w-0 flex-1 rounded-full bg-transparent px-4 text-sm outline-none focus:outline-none focus:ring-0 focus-visible:ring-0"
            aria-label="Telefon numarası"
          />
        ) : (
          <div className="relative w-0 min-w-0 flex-1">
            <textarea
              id="landing-prompt-input"
              ref={inputRef as React.RefObject<HTMLTextAreaElement>}
              value={displayValue}
              onChange={(e) => onInputChange(e.target.value)}
              onKeyDown={handleEnterToSend}
              onFocus={handleTextFocusOrClick}
              onClick={handleTextFocusOrClick}
              placeholder=""
              disabled={disabled}
              rows={1}
              className="max-h-40 min-h-[48px] w-full min-w-0 resize-none rounded-full bg-transparent px-4 py-3 text-sm outline-none focus:outline-none focus:ring-0 focus-visible:ring-0 disabled:opacity-70"
              aria-label="Mesajını yaz"
            />
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
