import { api, HttpError } from "./api";

export type NtfyResp<T> = { ok: boolean; status: number; data: T | null };

export type NtfyUser = {
  username: string;
  role: "admin" | "user";
  grants?: { topic: string; permission: string }[];
};

export type NtfyAccount = {
  username: string;
  role?: string;
  reservations?: {
    topic: string;
    owner_permission?: string;
    everyone_permission?: string;
  }[];
};

export type NtfyMessage = {
  id?: string;
  time?: number;
  topic?: string;
  title?: string;
  message?: string;
  priority?: number;
  tags?: string[];
  click?: string;
  attachment?: { name?: string; url?: string };
};

export const ntfy = {
  // ── Server overview ────────────────────────────────────────────────────
  overview: () =>
    api<{
      health: NtfyResp<{ healthy: boolean }>;
      version: NtfyResp<{ version?: string }>;
      stats: NtfyResp<{ messages?: number; messages_rate?: number }>;
      users: { ok: boolean; status: number; count: number | null; admins: number | null };
    }>("/ntfy/overview"),

  health: () => api<NtfyResp<{ healthy: boolean }>>("/ntfy/health"),
  version: () => api<NtfyResp<{ version?: string }>>("/ntfy/version"),
  stats: () => api<NtfyResp<{ messages?: number }>>("/ntfy/stats"),

  // ── Users ──────────────────────────────────────────────────────────────
  users: () => api<NtfyResp<NtfyUser[]>>("/ntfy/users"),

  createUser: (username: string, password: string, role: "user" | "admin" = "user") =>
    api<NtfyResp<unknown>>("/ntfy/users", {
      method: "PUT",
      body: { username, password, role }
    }),

  changePassword: (username: string, password: string) =>
    api<NtfyResp<unknown>>("/ntfy/users", {
      method: "PUT",
      body: { username, password }
    }),

  deleteUser: (username: string) =>
    api<NtfyResp<unknown>>("/ntfy/users", {
      method: "DELETE",
      body: { username }
    }),

  // ── ACL ────────────────────────────────────────────────────────────────
  setAccess: (username: string, topic: string, permission: string) =>
    api<NtfyResp<unknown>>("/ntfy/access", {
      method: "POST",
      body: { username, topic, permission }
    }),

  deleteAccess: (username: string, topic: string) =>
    api<NtfyResp<unknown>>("/ntfy/access", {
      method: "DELETE",
      body: { username, topic }
    }),

  // ── Account / Reservations ────────────────────────────────────────────
  account: () => api<NtfyResp<NtfyAccount>>("/ntfy/account"),

  addReservation: (topic: string, everyone: string) =>
    api<NtfyResp<unknown>>("/ntfy/account/reservation", {
      method: "POST",
      body: { topic, everyone }
    }),

  deleteReservation: (topic: string) =>
    api<NtfyResp<unknown>>(`/ntfy/account/reservation/${encodeURIComponent(topic)}`, {
      method: "DELETE"
    }),

  // ── Tokens ─────────────────────────────────────────────────────────────
  createToken: (label?: string, expires?: number) =>
    api<NtfyResp<{ token: string; expires?: number }>>("/ntfy/account/token", {
      method: "POST",
      body: { label, expires }
    }),

  // ── Publish ────────────────────────────────────────────────────────────
  publish: (input: {
    topic: string;
    message: string;
    title?: string;
    priority?: number;
    tags?: string;
    click?: string;
  }) =>
    api<NtfyResp<unknown>>("/ntfy/publish", {
      method: "POST",
      body: input
    }),

  // ── Messages (poll) ────────────────────────────────────────────────────
  messages: (topic: string, since: string, limit: number) =>
    api<{
      ok: boolean;
      messages: NtfyMessage[];
      errors: { topic: string; status: number; message?: string }[];
      topicCount: number;
      count: number;
    }>(`/ntfy/messages?topic=${encodeURIComponent(topic)}&since=${encodeURIComponent(since)}&limit=${limit}`)
};

/** Convenience: extract a friendly error message. */
export function ntfyErrorText(err: unknown): string {
  if (err instanceof HttpError) {
    const body: any = err.body;
    return body?.error || body?.message || `HTTP ${err.status}`;
  }
  return err instanceof Error ? err.message : String(err);
}
