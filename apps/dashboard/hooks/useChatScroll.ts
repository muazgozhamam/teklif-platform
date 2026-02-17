import { useEffect, useRef, useState } from "react";

type Options = {
  dependencyKey: string;
  bottomThreshold?: number;
};

export function useChatScroll({ dependencyKey, bottomThreshold = 120 }: Options) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [isAtBottom, setIsAtBottom] = useState(true);
  const [showScrollDown, setShowScrollDown] = useState(false);
  const [newBelowCount, setNewBelowCount] = useState(0);

  const previousKeyRef = useRef(dependencyKey);

  function measureAtBottom() {
    const el = containerRef.current;
    if (!el) return true;
    const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
    return distanceToBottom <= bottomThreshold;
  }

  function onScroll() {
    const atBottom = measureAtBottom();
    setIsAtBottom(atBottom);
    setShowScrollDown(!atBottom);
    if (atBottom) setNewBelowCount(0);
  }

  function scrollToBottom(smooth = true) {
    const el = containerRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: smooth ? "smooth" : "auto" });
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
