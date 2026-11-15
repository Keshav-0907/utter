"use client";

import { useEffect, useRef } from "react";

/**
 * A paragraph that lights up word by word as it is scrolled through the window:
 * pale to ink, tied to scroll position, not to a timer.
 */
export function ScrubText({ paragraphs, className }: { paragraphs: string[]; className?: string }) {
  const ref = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const words = Array.from(element.querySelectorAll<HTMLElement>("[data-word]"));
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      words.forEach((word) => (word.style.opacity = "1"));
      return;
    }

    let frame = 0;
    const update = () => {
      frame = 0;
      const rect = element.getBoundingClientRect();
      const view = window.innerHeight;
      // 0 when the block's top reaches 80% down the window, 1 when its bottom reaches 45%.
      const progress = (view * 0.8 - rect.top) / (rect.height + view * 0.35);
      const lit = Math.min(1, Math.max(0, progress)) * words.length;
      words.forEach((word, index) => {
        const amount = Math.min(1, Math.max(0, lit - index));
        word.style.opacity = String(0.2 + amount * 0.8);
      });
    };
    const onScroll = () => {
      if (!frame) frame = requestAnimationFrame(update);
    };
    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      if (frame) cancelAnimationFrame(frame);
    };
  }, []);

  return (
    <div ref={ref} className={className}>
      {paragraphs.map((paragraph, index) => (
        <p key={index}>
          {paragraph.split(" ").map((word, wordIndex) => (
            <span key={wordIndex} data-word>
              {word}{" "}
            </span>
          ))}
        </p>
      ))}
    </div>
  );
}
