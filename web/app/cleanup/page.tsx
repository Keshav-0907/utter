import type { Metadata } from "next";
import { Reveal } from "@/components/Reveal";

export const metadata: Metadata = {
  title: "Cleanup",
  description: "What Utter's cleanup fixes, how it decides when to step in, the models you can choose, and its limits.",
};

/** What was said, with the part Utter removes marked, and what it typed. All real output. */
const examples: { kind: string; said: (string | { cut: string })[]; typed: string }[] = [
  {
    kind: "You change your mind",
    said: ["Send it to ", { cut: "Rahul, no actually send it to " }, "Priya."],
    typed: "Send it to Priya.",
  },
  {
    kind: "You correct a detail",
    said: ["Add retries to the ", { cut: "fetch call, no actually the " }, "upload call."],
    typed: "Add retries to the upload call.",
  },
  {
    kind: "You correct a number",
    said: ["Use a batch size of ", { cut: "two hundred, sorry, " }, "five hundred."],
    typed: "Use a batch size of five hundred.",
  },
  {
    kind: "You stumble",
    said: ["Then run ", { cut: "the " }, "the tests and", { cut: ", um," }, " open a pull request."],
    typed: "Then run the tests and open a pull request.",
  },
  {
    kind: "You say a time",
    said: ["Schedule the migration for ", { cut: "three thirty" }, " tomorrow."],
    typed: "Schedule the migration for 3:30 tomorrow.",
  },
  {
    kind: "You ask a question",
    said: ["What is the capital of France?"],
    typed: "What is the capital of France?",
  },
];

const decisions = [
  [
    "Most sentences are left alone",
    "Speech recognition already adds punctuation and capitals. A sentence only goes to the language model if it contains a correcting word, a filler, a repeated word or a spelled-out number. Everything else is typed as heard.",
  ],
  [
    "A question stays a question",
    "The model is told your words are text to tidy, never a request to answer. Dictate a question or an instruction and you get that sentence back, not a reply to it.",
  ],
  [
    "The last version wins",
    "In “A, no B”, “A, sorry, B” or “A, I mean B”, Utter keeps B. If the model's rewrite has lost the word that came after the correction, the rewrite is thrown away.",
  ],
  [
    "When in doubt, your words",
    "A rewrite is only accepted if it is your words in your order, give or take the fixes. Anything else, or anything that takes too long, and Utter types exactly what you said.",
  ],
];

const models = [
  ["Apple Intelligence", "Nothing to download", "Not measured yet", "Built into macOS. Needs Apple Intelligence switched on."],
  ["Qwen3 0.6B", "350 MB", "About 0.2 s", "Punctuation and capitals. Misses most corrections."],
  ["Qwen3 1.7B", "1.0 GB", "About 0.3 s", "Handles corrections and stumbles. Suggested for a 16 GB Mac."],
  ["Qwen3 4B", "2.3 GB", "About 0.8 s", "The most careful of the three, and the slowest."],
];

const limits = [
  "A correction with no pause in it, like “this is good no bad”, is usually missed. It is typed as you said it.",
  "Spelled-out numbers are not always converted. “Thirty seconds” often stays as words.",
  "The model can drop a trailing clause. In testing, “set the timeout to thirty seconds and run the tests” once lost its second half.",
  "The test set is 20 sentences. The current score is 18 correct with none changed wrongly, which is a first check and not a benchmark.",
  "English only.",
];

export default function Cleanup() {
  return (
    <main className="doc">
      <section className="wrap doc-head">
        <Reveal step={90}>
          <h1>It fixes the sentence, not just the spelling.</h1>
          <p className="lede">
            Cleanup is an optional step that runs after speech recognition. A small language model on your Mac
            reads what you said and types what you meant. It is off until you pick a model.
          </p>
        </Reveal>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
          <h2>What it does with what you say</h2>
          <p>Every pair below is real output from Utter, using the Qwen3 1.7B model.</p>
        </Reveal>
        <Reveal as="ol" className="pairs" step={70}>
          {examples.map((row) => (
            <li key={row.typed + row.kind}>
              <span className="pair-kind">{row.kind}</span>
              <p className="pair-said">
                {row.said.map((part, index) =>
                  typeof part === "string" ? <span key={index}>{part}</span> : <s key={index}>{part.cut}</s>,
                )}
              </p>
              <p className="pair-typed">{row.typed}</p>
            </li>
          ))}
        </Reveal>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
          <h2>How it decides</h2>
          <p>A wrong rewrite is worse than no rewrite, so cleanup is built to step in rarely and back off easily.</p>
        </Reveal>
        <Reveal as="ul" className="rows" step={60}>
          {decisions.map(([title, text]) => (
            <li key={title}>
              <span>{title}</span>
              <span>{text}</span>
            </li>
          ))}
        </Reveal>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
          <h2>The models</h2>
          <p>
            Utter looks at your Mac's memory and suggests one. Press Download and it fetches the model, switches
            cleanup on and loads it. Times are typical for one sentence on a MacBook with an M4 chip.
          </p>
        </Reveal>
        <Reveal as="ul" className="rows four" step={60}>
          {models.map(([name, size, time, note]) => (
            <li key={name}>
              <span>{name}</span>
              <span className="value">{size}</span>
              <span className="value">{time}</span>
              <span className="note">{note}</span>
            </li>
          ))}
        </Reveal>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
          <h2>Where it still falls short</h2>
          <p>Small models make mistakes. These are the ones we know about.</p>
        </Reveal>
        <Reveal as="ul" className="rows single" step={50}>
          {limits.map((limit) => (
            <li key={limit}>
              <span>{limit}</span>
            </li>
          ))}
        </Reveal>
      </section>
    </main>
  );
}
