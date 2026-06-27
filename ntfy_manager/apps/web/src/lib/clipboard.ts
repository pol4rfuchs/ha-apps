/**
 * navigator.clipboard.writeText() is only available in secure contexts
 * (HTTPS or localhost). Most HAOS installs are plain HTTP on the LAN,
 * where navigator.clipboard is simply `undefined` — calling it throws
 * synchronously and the failure is silent (no toast, nothing copied).
 *
 * This mirrors the fallback the old ntfy admin panel already had.
 */
export async function copyToClipboard(text: string): Promise<boolean> {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // fall through to legacy fallback below
    }
  }

  try {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(textarea);
    return ok;
  } catch {
    return false;
  }
}
