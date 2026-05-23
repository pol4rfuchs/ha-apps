const KEY = "ntfy_admin_topics";

export function getTopics(fallback: string[]): string[] {
  const raw = localStorage.getItem(KEY);
  if (!raw) return fallback;
  return raw
    .split(",")
    .map((t) => t.trim())
    .filter(Boolean);
}

export function getTopicsString(fallback: string[]): string {
  return getTopics(fallback).join(",");
}

export function saveTopics(value: string): void {
  localStorage.setItem(KEY, value);
}

export function hasStoredTopics(): boolean {
  return !!localStorage.getItem(KEY);
}
