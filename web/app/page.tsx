import Link from "next/link";
import { Reveal } from "@/components/Reveal";
import { ScrubText } from "@/components/ScrubText";
import { Steps } from "@/components/Steps";
import { downloadUrl, githubUrl, latestVersion } from "@/lib/release";

const measured = [
  ["Transcribing an 8-second clip", "0.11 s", "Parakeet speech model"],
  ["Cleaning up one sentence", "0.3 s", "Typical time, Qwen3 1.7B"],
  ["Cleanup test sentences handled correctly", "18 of 20", "None of the 20 was changed wrongly"],
];

export default async function Home() {
  const version = await latestVersion();

  return (
    <main>
      {/* The headline and the film share the first screen: the film starts above the fold. */}
      <section className="wrap hero">
        <Reveal className="hero-top" step={90}>
          <h1>
            Dictation that types what you{" "}
            <span className="swap">
              <span className="swap-old" aria-hidden="true">
                said
              </span>
              <span className="swap-new">meant.</span>
            </span>
          </h1>
          <div className="hero-side">
            <p className="lede">
              Hold a key, speak, and Utter types it wherever your cursor is. Change your mind halfway through a
              sentence and it keeps the version you wanted.
            </p>
            <div className="actions">
              <a className="cap-button solid" href={downloadUrl}>
                Download .dmg <span className="version">({version})</span>
              </a>
              <a className="cap-button" href={githubUrl} target="_blank" rel="noreferrer">
                GitHub
              </a>
            </div>
          </div>
        </Reveal>
        <figure className="panel film">
          <video autoPlay muted loop playsInline preload="metadata" poster="/utter-demo-poster.jpg">
            <source src="/utter-demo.mp4" type="video/mp4" />
          </video>
        </figure>
      </section>

      {/* The argument, lit word by word as it is read, beside the correction happening on a loop. */}
      <section className="wrap statement">
        <ScrubText
          className="statement-text"
          paragraphs={[
            "Nobody speaks in finished sentences. You start, stop, pick the wrong name, and fix it three words later.",
            "Ordinary dictation types all of that. Utter types the sentence you ended up meaning, and it does it without sending a word off your Mac.",
          ]}
        />
        <div className="panel statement-panel" aria-hidden="true">
          <div className="demo">
            <span className="demo-label">You say</span>
            <p className="demo-line">
              Send it to <span className="demo-cut">Rahul, no actually send it to&nbsp;</span>Priya.
            </p>
            <span className="demo-label">Utter types</span>
            <p className="demo-result">Send it to Priya.</p>
          </div>
        </div>
      </section>

      <section className="wrap block">
        <Reveal className="block-head">
          <h2>Three movements, no settings.</h2>
        </Reveal>
        <Steps />
      </section>

      <section className="wrap block">
        <Reveal as="ul" className="doors" step={80}>
          <li>
            <Link href="/cleanup">
              <span className="door-title">Cleanup</span>
              <span className="door-text">
                What it fixes, how it decides, the models you can pick, and where it still gets things wrong.
              </span>
              <span className="door-go">Read</span>
            </Link>
          </li>
          <li>
            <Link href="/privacy">
              <span className="door-title">Privacy</span>
              <span className="door-text">
                What stays on your Mac, the only times Utter touches the internet, and how to remove every trace.
              </span>
              <span className="door-go">Read</span>
            </Link>
          </li>
        </Reveal>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
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
        <p className="fine">The cleanup test set is small, so read that last figure as a first check, not a benchmark.</p>
      </section>

      <section className="wrap">
        <Reveal className="panel closing" step={90}>
          <h2>Free, and open source.</h2>
          <p>No account, no subscription, no word limit. Read the code, or just use it.</p>
          <div className="actions">
            <a className="cap-button light" href={downloadUrl}>
              Download .dmg <span className="version">({version})</span>
            </a>
            <a className="cap-button ghost" href={githubUrl} target="_blank" rel="noreferrer">
              GitHub
            </a>
          </div>
          <p className="closing-note">
            For macOS 26 or later on Apple silicon. Utter is not yet notarized by Apple, so the first time you
            open it, go to System Settings, then Privacy &amp; Security, and choose Open Anyway.
          </p>
        </Reveal>
      </section>
    </main>
  );
}
