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

ntfyRouter.put("/users", async (req, res) => {
  const schema = z.object({
    username: z.string().min(1),
    password: z.string().min(1),
    role: z.enum(["admin", "user"]).optional()
  });
  const body = schema.parse(req.body);
  const r = await ntfyRequest("PUT", "/v1/users", { session: req.session, body });
  audit(r.ok ? "INFO" : "WARN", "users", `PUT user ${body.username} → ${r.status}`);
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});

ntfyRouter.delete("/users", async (req, res) => {
  const schema = z.object({ username: z.string().min(1) });
  const body = schema.parse(req.body);
  const r = await ntfyRequest("DELETE", "/v1/users", { session: req.session, body });
  audit(r.ok ? "INFO" : "WARN", "users", `DELETE user ${body.username} → ${r.status}`);
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
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
  const r = await ntfyRequest("POST", "/v1/access", { session: req.session, body });
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
  const r = await ntfyRequest("DELETE", "/v1/access", { session: req.session, body });
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

ntfyRouter.get("/account", async (req, res) => {
  const r = await ntfyRequest("GET", "/v1/account", { session: req.session });
  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
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
