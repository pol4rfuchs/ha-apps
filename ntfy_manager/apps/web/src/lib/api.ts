const API_BASE = "/api";

export type ApiError = {
  status: number;
  body: unknown;
  message: string;
};

export class HttpError extends Error implements ApiError {
  status: number;
  body: unknown;
  constructor(status: number, body: unknown, message: string) {
    super(message);
    this.status = status;
    this.body = body;
  }
}

export type ApiInit = Omit<RequestInit, "body"> & { body?: unknown };

export async function api<T>(path: string, init?: ApiInit): Promise<T> {
  const headers = new Headers(init?.headers);
  let body: BodyInit | undefined;
  if (init?.body !== undefined) {
    if (init.body instanceof FormData || typeof init.body === "string") {
      body = init.body as BodyInit;
    } else {
      headers.set("Content-Type", "application/json");
      body = JSON.stringify(init.body);
    }
  }

  const { body: _ignored, headers: _ignoredHeaders, ...rest } = init ?? {};
  void _ignored;
  void _ignoredHeaders;

  const res = await fetch(`${API_BASE}${path}`, {
    credentials: "include",
    ...rest,
    headers,
    body
  });

  let data: any = null;
  const text = await res.text();
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  if (!res.ok) {
    throw new HttpError(res.status, data, `HTTP ${res.status}`);
  }
  return data as T;
}
