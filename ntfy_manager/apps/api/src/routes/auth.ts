import { Router } from "express";
import { z } from "zod";
import rateLimit from "express-rate-limit";
import { env } from "../env.js";
import {
  basicAuthHeader,
  bearerAuthHeader,
  encryptSession,
  type SessionPayload
} from "../services/auth.js";
import { ntfyRequest } from "../ntfy/client.js";
import { attachSession, resolveSession, LOGGED_OUT_COOKIE_NAME } from "../middleware/auth.js";
import { audit } from "../services/logger.js";

export const authRouter = Router();

// CodeQL #244 (js/missing-rate-limiting): /login validates credentials
// against ntfy and must be protected against brute-force attempts.
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,                   // max 10 attempts per IP per window
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "too_many_attempts", message: "Zu viele Login-Versuche, bitte später erneut versuchen." }
});

const loginSchema = z.discriminatedUnion("authType", [
  z.object({
    authType: z.literal("basic"),
    username: z.string().min(1),
    password: z.string().min(1)
  }),
  z.object({
    authType: z.literal("bearer"),
    bearerToken: z.string().min(1)
  }),
  z.object({
    authType: z.literal("none")
  })
]);

/** GET /api/auth/status — used by login page to know what's available. */
authRouter.get("/status", attachSession, async (req, res) => {
  res.json({
    authenticated: !!req.session,
    username: req.session?.username ?? null,
    authType: req.session?.authType ?? null,
    defaultsConfigured: env.NTFY_AUTH_TYPE !== "none" || true,
    allowOverride: env.ALLOW_LOGIN_OVERRIDE,
    ntfyBaseUrl: env.NTFY_BASE_URL,
    defaultAuthType: env.NTFY_AUTH_TYPE,
    defaultUsername: env.NTFY_USERNAME || null
  });
});

/** POST /api/auth/login — validate creds against ntfy `/v1/account`, set cookie. */
authRouter.post("/login", loginLimiter, async (req, res) => {
  if (!env.ALLOW_LOGIN_OVERRIDE) {
    res.status(403).json({ error: "login_disabled_in_config" });
    return;
  }

  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_input", details: parsed.error.format() });
    return;
  }
  const body = parsed.data;

  // Build a tentative session so we can call ntfy with the proposed creds.
  let authHeader = "";
  let displayName = "(anonymous)";
  if (body.authType === "basic") {
    authHeader = basicAuthHeader(body.username, body.password);
    displayName = body.username;
  } else if (body.authType === "bearer") {
    authHeader = bearerAuthHeader(body.bearerToken);
    displayName = "(token)";
  }

  const probeSession: SessionPayload = {
    authType: body.authType,
    username: displayName,
    authHeader,
    iat: 0,
    exp: Math.floor(Date.now() / 1000) + 60
  };

  // Validate by calling /v1/account on ntfy.  Anonymous (`*`) will get back
  // a 200 with `{ "username": "*" }` — also fine.
  const probe = await ntfyRequest<{ username?: string; role?: string }>(
    "GET",
    "/v1/account",
    { session: probeSession }
  );

  if (probe.status === 0) {
    res.status(502).json({ error: "ntfy_unreachable", message: probe.error });
    return;
  }
  if (probe.status === 401) {
    res.status(401).json({ error: "invalid_credentials" });
    return;
  }
  if (!probe.ok) {
    res.status(probe.status).json({
      error: "ntfy_error",
      status: probe.status,
      detail: probe.data
    });
    return;
  }

  // Success — issue cookie.
  const now = Math.floor(Date.now() / 1000);
  const session: SessionPayload = {
    authType: body.authType,
    username: probe.data?.username || displayName,
    authHeader,
    iat: now,
    exp: now + 12 * 3600 // 12h
  };

  const token = encryptSession(session);
  res.cookie(env.SESSION_COOKIE_NAME, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: false, // ingress is HTTP internally
    maxAge: 12 * 3600 * 1000
  });
  res.clearCookie(LOGGED_OUT_COOKIE_NAME);

  audit("INFO", "auth", `Login OK: ${session.username} (${session.authType})`);
  res.json({
    ok: true,
    user: {
      username: session.username,
      role: probe.data?.role ?? null,
      authType: session.authType
    }
  });
});

/** POST /api/auth/logout — clear cookie and block fallback to add-on
 *  config defaults (e.g. the static HA bearer token), so this is a
 *  real logout instead of an instant silent re-login. */
authRouter.post("/logout", (req, res) => {
  res.clearCookie(env.SESSION_COOKIE_NAME);
  res.cookie(LOGGED_OUT_COOKIE_NAME, "1", {
    httpOnly: true,
    sameSite: "lax",
    secure: false,
    maxAge: 12 * 3600 * 1000
  });
  audit("INFO", "auth", "User logged out");
  res.json({ ok: true });
});

/** GET /api/auth/me — who am I right now (cookie or env defaults). */
authRouter.get("/me", (req, res) => {
  const s = resolveSession(req);
  if (!s) {
    res.status(401).json({ error: "not_authenticated" });
    return;
  }
  res.json({
    username: s.username,
    authType: s.authType,
    expiresAt: new Date(s.exp * 1000).toISOString()
  });
});
