import { NTFY_BASE } from "../env.js";
import type { SessionPayload } from "../services/auth.js";
import { audit } from "../services/logger.js";

export type NtfyResult<T = unknown> = {
  ok: boolean;
  status: number;
  data: T | null;
  rawText?: string;
  error?: string;
};

/** Build headers for a request, including Authorization if the session has one. */
function buildHeaders(session: SessionPayload | undefined, extra?: Record<string, string>): Headers {
  const h = new Headers(extra);
  if (session?.authHeader) h.set("Authorization", session.authHeader);
  if (!h.has("User-Agent")) h.set("User-Agent", "ntfy-haos-admin/0.2.0");
  return h;
}

/**
 * Generic ntfy API call. Always JSON in/out unless overridden.
 * Returns a flat NtfyResult — even network failures end up here, never throw.
 */
export async function ntfyRequest<T = unknown>(
  method: "GET" | "POST" | "PUT" | "DELETE",
  path: string,
  opts: {
    session?: SessionPayload;
    body?: unknown;
    headers?: Record<string, string>;
    raw?: boolean;
    /** Request timeout in ms. Default 10s — overridable for slow endpoints. */
    timeoutMs?: number;
  } = {}
): Promise<NtfyResult<T>> {
  const url = `${NTFY_BASE}${path.startsWith("/") ? path : `/${path}`}`;
  const headers = buildHeaders(opts.session, opts.headers);
  const init: RequestInit = {
    method,
    headers,
    signal: AbortSignal.timeout(opts.timeoutMs ?? 10_000)
  };

  if (opts.body !== undefined) {
    if (typeof opts.body === "string" || opts.body instanceof Uint8Array) {
      init.body = opts.body as BodyInit;
    } else {
      headers.set("Content-Type", "application/json");
      init.body = JSON.stringify(opts.body);
    }
  }

  try {
    const r = await fetch(url, init);
    const status = r.status;
    const text = await r.text();
    let data: T | null = null;
    if (!opts.raw) {
      try {
        data = text ? (JSON.parse(text) as T) : null;
      } catch {
        data = null;
      }
    }
    return { ok: r.ok, status, data, rawText: text };
  } catch (err) {
    const msg =
      err instanceof Error && err.name === "TimeoutError"
        ? `Timed out after ${opts.timeoutMs ?? 10_000}ms`
        : err instanceof Error
        ? err.message
        : String(err);
    audit("ERROR", "ntfy", `Request failed: ${method} ${path} → ${msg}`);
    return { ok: false, status: 0, data: null, error: msg };
  }
}

/** Stream-friendly variant — returns the Response directly for SSE/JSON-line bodies. */
export async function ntfyStream(
  path: string,
  opts: {
    session?: SessionPayload;
    headers?: Record<string, string>;
    signal?: AbortSignal;
  } = {}
): Promise<Response> {
  const url = `${NTFY_BASE}${path.startsWith("/") ? path : `/${path}`}`;
  return fetch(url, {
    method: "GET",
    headers: buildHeaders(opts.session, opts.headers),
    signal: opts.signal
  });
}

/** POST a publish request (raw body, custom headers — Title, Priority, Tags, Click). */
export async function ntfyPublish(
  topic: string,
  body: string,
  publishHeaders: Record<string, string>,
  session: SessionPayload | undefined
): Promise<NtfyResult<unknown>> {
  return ntfyRequest("POST", `/${encodeURIComponent(topic)}`, {
    session,
    body,
    headers: { "Content-Type": "text/plain; charset=utf-8", ...publishHeaders }
  });
}
