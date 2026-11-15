import Link from "next/link";
import { downloadUrl, githubUrl } from "@/lib/release";

/** Logo on the left; small capped links, each under its own hairline, and one solid button on the right. */
export function Nav() {
  return (
    <header className="nav">
      <div className="wrap nav-inner">
        <Link className="brand" href="/">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/icon.png" alt="" width={28} height={28} />
          Utter
        </Link>
        <nav>
          <Link className="nav-link" href="/cleanup">
            Cleanup
          </Link>
          <Link className="nav-link" href="/privacy">
            Privacy
          </Link>
          <a className="nav-link" href={githubUrl} target="_blank" rel="noreferrer">
            GitHub
          </a>
          <a className="cap-button solid" href={downloadUrl}>
            Download
          </a>
        </nav>
      </div>
    </header>
  );
}

export function Footer() {
  return (
    <footer className="wrap foot">
      <span>Utter. Dictation that stays on your Mac.</span>
      <nav>
        <Link href="/cleanup">Cleanup</Link>
        <Link href="/privacy">Privacy</Link>
        <a href={githubUrl} target="_blank" rel="noreferrer">
          GitHub
        </a>
      </nav>
    </footer>
  );
}
