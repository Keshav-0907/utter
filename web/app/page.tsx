import { Reveal } from "@/components/Reveal";
import { ScrubText } from "@/components/ScrubText";
import { Steps } from "@/components/Steps";
import { downloadUrl, githubUrl, latestVersion } from "@/lib/release";

/** All figures were measured on a MacBook with an M4 chip and 16 GB of memory. */
const transcription = [
  { label: "Saying the sentence", seconds: 8.2, note: "how long the speech itself lasts" },
  { label: "Apple Speech", seconds: 0.28, note: "built into macOS" },
  { label: "Parakeet", seconds: 0.11, note: "optional download" },
];

const cleanupTime = [
  { label: "Qwen3 0.6B", seconds: 0.2, note: "light fixes only" },
  { label: "Qwen3 1.7B", seconds: 0.3, note: "18 of 20 correct" },
  { label: "Qwen3 4B", seconds: 0.8, note: "18 of 20 correct" },
];

const pace = [
  { label: "Typing", words: 40, note: "a commonly cited average" },
  { label: "Dictating with Utter", words: 129, note: "one person's running average in the app" },
];

/** The 20 test sentences, one mark each: right, left exactly as said, or changed wrongly. */
const accuracy = [
  { label: "Model on its own", right: 15, untouched: 2, wrong: 3 },
  { label: "With Utter's checks", right: 18, untouched: 2, wrong: 0 },
];

const compare: [string, string, string, string][] = [
  ["Where your voice is processed", "On the company's servers", "On your Mac", "On your Mac"],
  ["Works with no internet", "No", "Yes", "Yes"],
  ["Fixes a mid-sentence correction", "Yes, on their servers", "No. It types every word, slips included", "Yes, on your Mac"],
  ["Price", "Usually a monthly subscription", "Free", "Free"],
  ["Code you can read", "Rarely", "No", "Yes"],
];

/** `accentLast` paints the final bar blue, for charts where the last row is the point being made. */
function Bars({
  rows,
  max,
  unit,
  accentLast = false,
}: {
  rows: { label: string; value: number; note: string }[];
  max: number;
  unit: string;
  accentLast?: boolean;
}) {
  return (
    <ul className={accentLast ? "bars-chart accent-last" : "bars-chart"}>
      {rows.map((row) => (
        <li key={row.label}>
          <span className="bar-label">{row.label}</span>
          <span className="bar-track">
            <span className="bar-fill" style={{ width: `${Math.max(0.6, (row.value / max) * 100)}%` }} />
          </span>
          <span className="bar-value">
            {row.value} {unit}
          </span>
          <span className="bar-note">{row.note}</span>
        </li>
      ))}
    </ul>
  );
}

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

      {/* Straight after the film: what was measured, drawn so it can be read at a glance. */}
      <section className="wrap block" id="measured">
        <Reveal className="block-head split">
          <h2>Measured, not promised.</h2>
          <p>
            Every number here was timed on one ordinary laptop: a MacBook with an M4 chip and 16 GB of memory.
            Nothing was sent to a server to get them.
          </p>
        </Reveal>

        <div className="charts">
          <Reveal className="panel chart wide">
            <span className="chart-kicker">Turning speech into text</span>
            <p className="chart-claim">An 8-second sentence is transcribed in about a tenth of a second.</p>
            <Bars rows={transcription.map((row) => ({ label: row.label, value: row.seconds, note: row.note }))} max={8.2} unit="s" accentLast />
          </Reveal>

          <Reveal className="panel chart">
            <span className="chart-kicker">Speaking against typing</span>
            <p className="chart-claim">About three times the words per minute.</p>
            <Bars rows={pace.map((row) => ({ label: row.label, value: row.words, note: row.note }))} max={129} unit="wpm" accentLast />
          </Reveal>

          <Reveal className="panel chart wide">
            <span className="chart-kicker">Cleanup on 20 test sentences</span>
            <p className="chart-claim">With Utter's checks, 18 come out right and none come out wrong.</p>
            <ul className="dots-chart">
              {accuracy.map((row) => (
                <li key={row.label}>
                  <span className="bar-label">{row.label}</span>
                  <span className="dots" role="img" aria-label={`${row.right} right, ${row.untouched} left as said, ${row.wrong} wrong`}>
                    {Array.from({ length: row.right }, (_, index) => <i key={`r${index}`} className="dot right" />)}
                    {Array.from({ length: row.untouched }, (_, index) => <i key={`u${index}`} className="dot untouched" />)}
                    {Array.from({ length: row.wrong }, (_, index) => <i key={`w${index}`} className="dot wrong" />)}
                  </span>
                  <span className="bar-note">
                    {row.right} right, {row.untouched} left as said, {row.wrong} wrong
                  </span>
                </li>
              ))}
            </ul>
            <p className="chart-key">
              <span><i className="dot right" /> Cleaned up correctly</span>
              <span><i className="dot untouched" /> Typed exactly as said</span>
              <span><i className="dot wrong" /> Changed wrongly</span>
            </p>
          </Reveal>

          <Reveal className="panel chart">
            <span className="chart-kicker">Time to clean up one sentence</span>
            <p className="chart-claim">Under a second with every model.</p>
            <Bars rows={cleanupTime.map((row) => ({ label: row.label, value: row.seconds, note: row.note }))} max={1} unit="s" />
          </Reveal>
        </div>
        <p className="fine wide">
          The cleanup test is 20 sentences, so treat it as a first check, not a benchmark. Typing speed is a
          general figure, not something we measured.
        </p>
      </section>

      {/* How the usual way works, and how this one does. */}
      <section className="wrap block" id="compare">
        <Reveal className="block-head split">
          <h2>Where your words go.</h2>
          <p>
            Most dictation apps record you, send the audio to their servers, and send text back. Utter does
            the whole job on the machine in front of you.
          </p>
        </Reveal>

        <Reveal className="routes" step={120}>
          <div className="route">
            <span className="route-name">Cloud dictation</span>
            <ol>
              <li>Your voice</li>
              <li className="away">The internet</li>
              <li className="away">Their servers</li>
              <li className="away">The internet</li>
              <li>Your text</li>
            </ol>
          </div>
          <div className="route ours">
            <span className="route-name">Utter</span>
            <ol>
              <li>Your voice</li>
              <li className="here">Your Mac</li>
              <li>Your text</li>
            </ol>
          </div>
        </Reveal>

        <Reveal className="compare" step={50}>
          <div className="compare-row compare-head">
            <span />
            <span>Cloud dictation apps</span>
            <span>Dictation built into macOS</span>
            <span>Utter</span>
          </div>
          {compare.map(([what, cloud, builtIn, utter]) => (
            <div className="compare-row" key={what}>
              <span>{what}</span>
              <span>{cloud}</span>
              <span>{builtIn}</span>
              <span className="us">{utter}</span>
            </div>
          ))}
        </Reveal>
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
