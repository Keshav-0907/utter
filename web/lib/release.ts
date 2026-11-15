const REPO = "Keshav-0907/utter";

export const githubUrl = `https://github.com/${REPO}`;
/** Always points at the newest build: the release workflow names the file the same every time. */
export const downloadUrl = `${githubUrl}/releases/latest/download/Utter.dmg`;

/** Shown if GitHub cannot be reached when the page is built. */
const FALLBACK_VERSION = "0.1.0";

/** The latest released version, e.g. "0.1.0" from the tag "v0.1.0-build.3". Refreshed hourly. */
export async function latestVersion(): Promise<string> {
  try {
    const response = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" },
      next: { revalidate: 3600 },
    });
    if (!response.ok) return FALLBACK_VERSION;
    const release = (await response.json()) as { tag_name?: string };
    const match = release.tag_name?.match(/^v?(\d+\.\d+\.\d+)/);
    return match ? match[1] : FALLBACK_VERSION;
  } catch {
    return FALLBACK_VERSION;
  }
}
