import { useEffect, useRef, useState } from "react";

type Options = {
  dependencyKey: string;
};

export function useChatScroll({ dependencyKey }: Options) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [isAtBottom, setIsAtBottom] = useState(true);
  const [showScrollDown, setShowScrollDown] = useState(false);
  const [newBelowCount, setNewBelowCount] = useState(0);

  const previousKeyRef = useRef(dependencyKey);

  function measureAtBottom() {
    const el = containerRef.current;
    if (!el) return true;
    const threshold = 80;
    const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
    return distanceToBottom <= threshold;
  }

  function onScroll() {
    const atBottom = measureAtBottom();
    setIsAtBottom(atBottom);
    setShowScrollDown(!atBottom);
    if (atBottom) setNewBelowCount(0);
  }

  function scrollToBottom() {
    const el = containerRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
    setIsAtBottom(true);
    setShowScrollDown(false);
    setNewBelowCount(0);
  }

  useEffect(() => {
    const nextKey = dependencyKey;
    const previousKey = previousKeyRef.current;
    if (nextKey === previousKey) return;
    previousKeyRef.current = nextKey;

    const atBottom = measureAtBottom();
    if (atBottom) {
      requestAnimationFrame(() => {
        const el = containerRef.current;
        if (!el) return;
        el.scrollTop = el.scrollHeight;
      });
      setShowScrollDown(false);
      setNewBelowCount(0);
      return;
    }

    setShowScrollDown(true);
    setNewBelowCount((prev) => prev + 1);
  }, [dependencyKey]);

  return {
    containerRef,
    isAtBottom,
    showScrollDown,
    newBelowCount,
    onScroll,
    scrollToBottom,
  };
}

