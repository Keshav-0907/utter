import { Reveal } from "@/components/Reveal";
import { downloadUrl, githubUrl, latestVersion } from "@/lib/release";

/** What was said, with the part Utter removes marked, and what it typed. All real output. */
const corrections: { said: (string | { cut: string })[]; typed: string; kind: string }[] = [
  {
    kind: "You change your mind",
    said: ["Send it to ", { cut: "Rahul, no actually send it to " }, "Priya."],
    typed: "Send it to Priya.",
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
];

const local = [
  ["Your voice", "Turned into text on your Mac. The audio is never uploaded or kept."],
  ["Cleanup", "Done by a small language model that also runs on your Mac."],
  ["History and stats", "Saved in a file in your Library folder. Delete it any time."],
  ["Models", "Downloaded once, then everything works with Wi-Fi off."],
  ["Account and tracking", "There is no account, and the app sends no analytics."],
];

const measured = [
  ["Transcribing an 8-second clip", "0.11 s", "Parakeet speech model"],
  ["Cleaning up one sentence", "0.3 s", "Typical time, Qwen3 1.7B"],
  ["Cleanup test sentences handled correctly", "18 of 20", "None of the 20 was changed wrongly"],
];

function DownloadButtons({ version }: { version: string }) {
  return (
    <div className="actions">
      <a className="button primary" href={downloadUrl}>
        Download .dmg <span className="version">({version})</span>
      </a>
      <a className="button" href={githubUrl} target="_blank" rel="noreferrer">
        View on GitHub
      </a>
    </div>
  );
}

export default async function Home() {
  const version = await latestVersion();

  return (
    <>
      <header className="bar">
        <div className="wrap bar-inner">
          <a className="brand" href="#top">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/icon.png" alt="" width={26} height={26} />
            Utter
          </a>
          <nav>
            <a href="#cleanup">Cleanup</a>
            <a href="#private">Privacy</a>
            <a href={githubUrl} target="_blank" rel="noreferrer">
              GitHub
            </a>
          </nav>
        </div>
      </header>

      <main id="top">
        <section className="wrap hero">
          <Reveal step={90}>
            <h1>
              Dictation that types what you{" "}
              <span className="swap">
                <span className="swap-old" aria-hidden="true">
                  said
                </span>
                <span className="swap-new">meant.</span>
              </span>
            </h1>
            <p className="lede">
              Hold a key, speak, and Utter types it wherever your cursor is. Change your mind halfway through a
              sentence and it keeps the version you wanted. It runs on your Mac and it is free.
            </p>
            <DownloadButtons version={version} />
            <p className="fine">For macOS 26 or later on Apple silicon.</p>
          </Reveal>
        </section>

        <section className="wrap">
          <Reveal>
            <figure className="frame">
              <video autoPlay muted loop playsInline preload="metadata" poster="/utter-demo-poster.jpg">
                <source src="/utter-demo.mp4" type="video/mp4" />
              </video>
            </figure>
          </Reveal>
        </section>

        <section className="wrap section" id="cleanup">
          <Reveal className="section-head">
            <h2>It fixes the sentence, not just the spelling.</h2>
            <p>
              Nobody speaks in finished sentences. Utter listens for the moment you correct yourself and types
              only what you ended up meaning. If its rewrite ever strays from your words, it types exactly what
              you said.
            </p>
          </Reveal>
          <Reveal as="ol" className="pairs" step={90}>
            {corrections.map((row) => (
              <li key={row.typed}>
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

        <section className="wrap section" id="private">
          <Reveal className="section-head">
            <h2>Nothing you say leaves your Mac.</h2>
            <p>
              Most dictation tools send your voice to a server. Utter does the listening and the cleanup on your
              own machine, so what you dictate stays with you.
            </p>
          </Reveal>
          <Reveal as="ul" className="rows" step={60}>
            {local.map(([what, where]) => (
              <li key={what}>
                <span>{what}</span>
                <span>{where}</span>
              </li>
            ))}
          </Reveal>
        </section>

        <section className="wrap section" id="speed">
          <Reveal className="section-head">
            <h2>Fast enough that you stop noticing it.</h2>
            <p>Measured on a MacBook with an M4 chip and 16 GB of memory.</p>
          </Reveal>
          <Reveal as="ul" className="rows measured" step={60}>
            {measured.map(([what, value, note]) => (
              <li key={what}>
                <span>{what}</span>
                <span className="value">{value}</span>
                <span className="note">{note}</span>
              </li>
            ))}
          </Reveal>
          <Reveal>
            <p className="fine">
              The cleanup test set is small, so read that last figure as a first check, not a benchmark.
            </p>
          </Reveal>
        </section>

        <section className="wrap section closing">
          <Reveal step={90}>
            <h2>Free, and open source.</h2>
            <p className="lede">No account, no subscription, no word limit. Read the code, or just use it.</p>
            <DownloadButtons version={version} />
            <details>
              <summary>The first launch takes one extra step</summary>
              <p>
                Utter is not yet notarized by Apple, so macOS blocks it the first time. Open System Settings,
                go to Privacy &amp; Security, scroll down and choose Open Anyway next to Utter. After that,
                allow Microphone and Accessibility access when it asks.
              </p>
            </details>
          </Reveal>
        </section>
      </main>

      <footer className="wrap foot">
        <span>Utter</span>
        <a href={githubUrl} target="_blank" rel="noreferrer">
          GitHub
        </a>
      </footer>
    </>
  );
}
