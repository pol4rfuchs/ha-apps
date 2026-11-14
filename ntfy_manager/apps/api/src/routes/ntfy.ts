import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { ntfyRequest } from "../ntfy/client.js";
import { audit } from "../services/logger.js";

/**
 * Proxy router for ntfy admin REST API.
 *
 * Why proxy instead of letting the browser hit ntfy directly?
 *   - The browser never sees the credentials (cookie holds them encrypted).
 *   - Single origin → no CORS surface from the panel.
 *   - All API calls land in our audit log automatically.
 *
 * All endpoints require an authenticated session (cookie or env default).
 */
export const ntfyRouter = Router();

ntfyRouter.use(requireAuth);

// ---------------------------------------------------------------------------
// Server health / version / stats
// ---------------------------------------------------------------------------

ntfyRouter.get("/health", async (req, res) => {
  const r = await ntfyRequest("GET", "/v1/health", { session: req.session });
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

ntfyRouter.get("/version", async (req, res) => {
  const r = await ntfyRequest("GET", "/v1/version", { session: req.session });
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

ntfyRouter.get("/stats", async (req, res) => {
  const r = await ntfyRequest("GET", "/v1/stats", { session: req.session });
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

// Aggregated overview — saves the frontend three round-trips
ntfyRouter.get("/overview", async (req, res) => {
  const [health, version, stats, users] = await Promise.all([
    ntfyRequest("GET", "/v1/health", { session: req.session }),
    ntfyRequest("GET", "/v1/version", { session: req.session }),
    ntfyRequest("GET", "/v1/stats", { session: req.session }),
    ntfyRequest<unknown[]>("GET", "/v1/users", { session: req.session })
  ]);

  res.json({
    health: { ok: health.ok, status: health.status, data: health.data },
    version: { ok: version.ok, status: version.status, data: version.data },
    stats: { ok: stats.ok, status: stats.status, data: stats.data },
    users: {
      ok: users.ok,
      status: users.status,
      count: Array.isArray(users.data) ? users.data.length : null,
      admins: Array.isArray(users.data)
        ? users.data.filter((u: any) => u?.role === "admin").length
        : null
    }
  });
});

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

ntfyRouter.get("/users", async (req, res) => {
  const r = await ntfyRequest("GET", "/v1/users", { session: req.session });
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

/**
 * ntfy >= 2.37 only accepts some user changes over its local admin socket,
 * which this app cannot reach (the socket is a file inside the ntfy container).
 * ntfy then answers 403 "forbidden: this operation is only allowed over the
 * local admin socket" (code 40302). Turn that into a message the panel can show.
 */
const ADMIN_SOCKET_MESSAGE =
  "ntfy only allows this over its local admin socket, which the panel cannot reach. " +
  "Use the ntfy command line in the ntfy app instead (for example: ntfy user change-role, " +
  "ntfy user change-pass, ntfy user del).";

function isAdminSocketOnly(r: { status: number; data: unknown; rawText?: string }): boolean {
  if (r.status !== 403) return false;
  const code = (r.data as { code?: number } | null)?.code;
  return code === 40302 || (r.rawText ?? "").includes("local admin socket");
}

function sendUserResult(
  res: import("express").Response,
  r: { ok: boolean; status: number; data: unknown; rawText?: string; error?: string }
) {
  if (isAdminSocketOnly(r)) {
    res.status(403).json({
      ok: false,
      status: 403,
      data: r.data,
      error: ADMIN_SOCKET_MESSAGE,
      reason: "admin_socket_only"
    });
    return;
  }
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
}

ntfyRouter.put("/users", async (req, res) => {
  const schema = z.object({
    username: z.string().min(1),
    password: z.string().min(1),
    role: z.enum(["admin", "user"]).optional()
  });
  const body = schema.parse(req.body);
  // ntfy 2.37 answers 403 (admin socket only) as soon as the request body has a
  // "role" field, even "user". Creating a user and changing a password work
  // without it, and a new user is a regular user anyway, so never forward the
  // role. The panel already tells the admin to run `ntfy user change-role`.
  const forwarded = { username: body.username, password: body.password };
  const r = await ntfyRequest("PUT", "/v1/users", { session: req.session, body: forwarded });
  audit(r.ok ? "INFO" : "WARN", "users", `PUT user ${body.username} → ${r.status}`);
  sendUserResult(res, r);
});

ntfyRouter.delete("/users", async (req, res) => {
  const schema = z.object({ username: z.string().min(1) });
  const body = schema.parse(req.body);
  const r = await ntfyRequest("DELETE", "/v1/users", { session: req.session, body });
  audit(r.ok ? "INFO" : "WARN", "users", `DELETE user ${body.username} → ${r.status}`);
  sendUserResult(res, r);
});

// ---------------------------------------------------------------------------
// Access (ACL)
// ---------------------------------------------------------------------------

ntfyRouter.post("/access", async (req, res) => {
  const schema = z.object({
    username: z.string().min(1),
    topic: z.string().min(1),
    permission: z.enum(["read-write", "read-only", "write-only", "deny-all"])
  });
  const body = schema.parse(req.body);
  const r = await ntfyRequest("POST", "/v1/users/access", { session: req.session, body });
  audit(
    r.ok ? "INFO" : "WARN",
    "acl",
    `POST access ${body.username}/${body.topic}=${body.permission} → ${r.status}`
  );
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

ntfyRouter.delete("/access", async (req, res) => {
  const schema = z.object({
    username: z.string().min(1),
    topic: z.string().min(1)
  });
  const body = schema.parse(req.body);
  const r = await ntfyRequest("DELETE", "/v1/users/access", { session: req.session, body });
  audit(
    r.ok ? "INFO" : "WARN",
    "acl",
    `DELETE access ${body.username}/${body.topic} → ${r.status}`
  );
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

// ---------------------------------------------------------------------------
// Account / Reservations
// ---------------------------------------------------------------------------

/**
 * ntfy lists the full access tokens of the account in /v1/account. The panel
 * never needs them (it only reads the username and the reservations), so hide
 * all but the first characters before the response leaves the backend.
 */
function maskTokens(data: unknown): unknown {
  if (!data || typeof data !== "object") return data;
  const account = data as { tokens?: unknown };
  if (!Array.isArray(account.tokens)) return data;
  return {
    ...account,
    tokens: account.tokens.map((t) =>
      t && typeof t === "object" && typeof (t as { token?: unknown }).token === "string"
        ? { ...t, token: `${(t as { token: string }).token.slice(0, 7)}…` }
        : t
    )
  };
}

ntfyRouter.get("/account", async (req, res) => {
  const r = await ntfyRequest("GET", "/v1/account", { session: req.session });
  res.status(r.status || 502).json({ ok: r.ok, data: maskTokens(r.data), status: r.status });
});

/**
 * Topic Reservation. ntfy expects `{ topic, everyone }` in the body
 * for POST /v1/account/reservation (this was the bug that bit us before — do
 * NOT put `topic` in the URL path).
 */
ntfyRouter.post("/account/reservation", async (req, res) => {
  const schema = z.object({
    topic: z.string().min(1),
    everyone: z.enum(["read-write", "read-only", "write-only", "deny-all"])
  });
  const body = schema.parse(req.body);
  const r = await ntfyRequest("POST", "/v1/account/reservation", { session: req.session, body });
  audit(
    r.ok ? "INFO" : "WARN",
    "reservation",
    `POST reservation ${body.topic}=${body.everyone} → ${r.status}`
  );
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

ntfyRouter.delete("/account/reservation/:topic", async (req, res) => {
  const topic = req.params.topic;
  const r = await ntfyRequest(
    "DELETE",
    `/v1/account/reservation/${encodeURIComponent(topic)}`,
    { session: req.session }
  );
  audit(r.ok ? "INFO" : "WARN", "reservation", `DELETE reservation ${topic} → ${r.status}`);
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

// ---------------------------------------------------------------------------
// Tokens
// ---------------------------------------------------------------------------

ntfyRouter.post("/account/token", async (req, res) => {
  const schema = z.object({
    label: z.string().optional(),
    expires: z.number().optional()
  });
  const body = schema.parse(req.body ?? {});
  const r = await ntfyRequest("POST", "/v1/account/token", { session: req.session, body });
  audit(r.ok ? "INFO" : "WARN", "token", `POST token (${body.label ?? "no label"}) → ${r.status}`);
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});
