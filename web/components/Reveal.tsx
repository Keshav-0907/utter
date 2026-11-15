"use client";

import { useEffect, useRef, type CSSProperties, type ReactNode } from "react";

/**
 * Brings its children in once, when they scroll into view: each direct child
 * sharpens out of a blur and rises a few pixels, one after another.
 * The motion itself lives in globals.css under [data-reveal].
 */
export function Reveal({
  children,
  className,
  step = 70,
  as: Tag = "div",
}: {
  children: ReactNode;
  className?: string;
  /** Milliseconds between one child starting and the next. */
  step?: number;
  as?: "div" | "section" | "ul" | "ol" | "p" | "h1" | "h2" | "header" | "footer";
}) {
  const ref = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    Array.from(element.children).forEach((child, index) => {
      (child as HTMLElement).style.setProperty("--i", String(index));
    });
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          element.setAttribute("data-shown", "");
          observer.disconnect();
        }
      },
      { rootMargin: "0px 0px -12% 0px", threshold: 0.05 },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  return (
    // @ts-expect-error one ref type for a small fixed set of tags
    <Tag ref={ref} className={className} data-reveal style={{ "--step": `${step}ms` } as CSSProperties}>
      {children}
    </Tag>
  );
}
