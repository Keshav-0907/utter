import type { Metadata } from "next";
import { Reveal } from "@/components/Reveal";
import { githubUrl } from "@/lib/release";

export const metadata: Metadata = {
  title: "Privacy",
  description: "What Utter keeps on your Mac, the only times it uses the internet, and how to remove it completely.",
};

const stays = [
  ["Your voice", "Turned into text on your Mac by the speech model you chose. The audio is held in memory while you speak and discarded when the text is typed. It is never written to disk or uploaded."],
  ["Cleanup", "Run by a language model on your Mac. Your sentences are not sent to any service to be rewritten."],
  ["History", "Your past dictations are saved in one file on your Mac so you can copy them again. You can clear it, or switch history off, in the app."],
  ["Statistics", "Word counts and speaking pace are kept in the app's settings on your Mac."],
  ["Account", "There is none. Utter has no sign-in and no licence key."],
  ["Analytics", "There are none. The app does not report usage, crashes or anything else."],
];

const online = [
  ["Downloading a model", "The first time you choose Parakeet or a Qwen3 cleanup model, Utter fetches its files from Hugging Face. That request carries no information about you beyond what any download does."],
  ["Apple's speech and language models", "If you use Apple's built-in options, macOS manages and updates those models itself."],
  ["Nothing else", "With the models in place, Utter works with Wi-Fi off. It does not check for updates on its own."],
];

const permissions = [
  ["Microphone", "To hear you. Utter only listens while you hold the key, or between the two taps of hands-free mode, and it stops by itself after ten minutes at most."],
  ["Accessibility", "To notice the dictation key in any app and to type the result at your cursor. macOS groups both under Accessibility."],
];

const files = [
  ["~/Library/Application Support/Utter", "History, and any cleanup models you downloaded."],
  ["~/Library/Application Support/FluidAudio", "The Parakeet speech model, if you downloaded it."],
  ["Utter in your Applications folder", "The app itself."],
];

export default function Privacy() {
  return (
    <main className="doc">
      <section className="wrap doc-head">
        <Reveal step={90}>
          <h1>Nothing you say leaves your Mac.</h1>
          <p className="lede">
            Most dictation tools send your voice to a server. Utter does the listening and the cleanup on your
            own machine. This page lists exactly what it stores, when it goes online, and how to remove it.
          </p>
        </Reveal>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
          <h2>What stays on your Mac</h2>
          <p>Everything.</p>
        </Reveal>
        <Reveal as="ul" className="rows" step={60}>
          {stays.map(([what, detail]) => (
            <li key={what}>
              <span>{what}</span>
              <span>{detail}</span>
            </li>
          ))}
        </Reveal>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
          <h2>When Utter uses the internet</h2>
          <p>Only to fetch a model you asked for.</p>
        </Reveal>
        <Reveal as="ul" className="rows" step={60}>
          {online.map(([what, detail]) => (
            <li key={what}>
              <span>{what}</span>
              <span>{detail}</span>
            </li>
          ))}
        </Reveal>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
          <h2>What it asks permission for</h2>
          <p>Two things, both needed for dictation to work at all.</p>
        </Reveal>
        <Reveal as="ul" className="rows" step={60}>
          {permissions.map(([what, detail]) => (
            <li key={what}>
              <span>{what}</span>
              <span>{detail}</span>
            </li>
          ))}
        </Reveal>
        <p className="fine wide">
          One detail worth knowing: to type into other apps, Utter briefly places the text on your clipboard,
          pastes it, and then puts back what was there before.
        </p>
      </section>

      <section className="wrap block">
        <Reveal className="block-head split">
          <h2>Removing every trace</h2>
          <p>Quit Utter, then delete these. Nothing else is left behind.</p>
        </Reveal>
        <Reveal as="ul" className="rows" step={60}>
          {files.map(([path, what]) => (
            <li key={path}>
              <span className="path">{path}</span>
              <span>{what}</span>
            </li>
          ))}
        </Reveal>
        <p className="fine wide">
          You do not have to take this on trust. The whole app is{" "}
          <a className="text-link" href={githubUrl} target="_blank" rel="noreferrer">
            open on GitHub
          </a>
          .
        </p>
      </section>
    </main>
  );
}
