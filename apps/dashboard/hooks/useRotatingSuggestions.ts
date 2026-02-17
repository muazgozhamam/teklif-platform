import { useEffect, useMemo, useState } from "react";

type Options = {
  suggestions: string[];
  active: boolean;
};

export function useRotatingSuggestions({ suggestions, active }: Options) {
  const safeSuggestions = useMemo(
    () => (suggestions.length > 0 ? suggestions : ["Danışman olmak istiyorum."]),
    [suggestions],
  );
  const [text, setText] = useState("");
  const [index, setIndex] = useState(0);
  const [isDeleting, setIsDeleting] = useState(false);
  const [cursorVisible, setCursorVisible] = useState(true);

  useEffect(() => {
    if (!active) {
      setText("");
      setIsDeleting(false);
      return;
    }

    const sample = safeSuggestions[index] ?? "";
    let delay = 50;

    if (!isDeleting && text.length < sample.length) delay = 40;
    else if (!isDeleting && text.length === sample.length) delay = 1400;
    else if (isDeleting && text.length > 0) delay = 24;
    else delay = 280;

    const timer = window.setTimeout(() => {
      if (!isDeleting && text.length < sample.length) {
        setText(sample.slice(0, text.length + 1));
        return;
      }

      if (!isDeleting && text.length === sample.length) {
        setIsDeleting(true);
        return;
      }

      if (isDeleting && text.length > 0) {
        setText(sample.slice(0, text.length - 1));
        return;
      }

      setIsDeleting(false);
      setIndex((prev) => (prev + 1) % safeSuggestions.length);
    }, delay);

    return () => window.clearTimeout(timer);
  }, [active, index, isDeleting, safeSuggestions, text]);

  useEffect(() => {
    if (!active) {
      setCursorVisible(false);
      return;
    }
    setCursorVisible(true);
    const timer = window.setInterval(() => {
      setCursorVisible((prev) => !prev);
    }, 480);
    return () => window.clearInterval(timer);
  }, [active]);

  return { text, cursorVisible };
}

