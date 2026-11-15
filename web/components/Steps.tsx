"use client";

import { useEffect, useRef, useState } from "react";

const steps = [
  {
    title: "Hold the key",
    body: "Right Option by default. Utter starts listening the moment it goes down, in whatever app you are in.",
  },
  {
    title: "Say it how it comes",
    body: "Pause, restart, change your mind. Double-tap the key if you would rather not hold it.",
  },
  {
    title: "Let go",
    body: "The cleaned-up sentence is typed at your cursor, usually in about a third of a second.",
  },
];

/** A large panel that stays in view while three steps scroll past; the panel shows the current step. */
export function Steps() {
  const [active, setActive] = useState(0);
  const items = useRef<(HTMLLIElement | null)[]>([]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) setActive(Number((entry.target as HTMLElement).dataset.index));
        });
      },
      { rootMargin: "-45% 0px -45% 0px" },
    );
    items.current.forEach((item) => item && observer.observe(item));
    return () => observer.disconnect();
  }, []);

  return (
    <div className="steps">
      <div className="steps-panel panel" data-active={active} aria-hidden="true">
        <div className="scene scene-key">
          <div className="keycap">
            <span>⌥</span>
            <span>option</span>
          </div>
        </div>
        <div className="scene scene-speak">
          <div className="pill">
            <span className="bars">
              <i /><i /><i /><i /><i /><i /><i />
            </span>
            Send it to Rahul, no actually send it to Priya
          </div>
        </div>
        <div className="scene scene-type">
          <p className="typed">
            Send it to Priya.<span className="caret" />
          </p>
          <p className="typed-note">Cleaned up in 0.3 s</p>
        </div>
      </div>

      <ol className="steps-list">
        {steps.map((step, index) => (
          <li
            key={step.title}
            data-index={index}
            data-on={active === index ? "" : undefined}
            ref={(element) => {
              items.current[index] = element;
            }}
          >
            <h3>
              <span className="step-number">0{index + 1}</span>
              {step.title}
            </h3>
            <p>{step.body}</p>
          </li>
        ))}
      </ol>
    </div>
  );
}
