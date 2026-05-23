import { Router } from "express";
import { DEFAULT_TOPICS, env } from "../env.js";
import { resolveSession } from "../middleware/auth.js";

export const configRouter = Router();

/** Public — used by the login page and topic settings. */
configRouter.get("/", (req, res) => {
  const s = resolveSession(req);
  res.json({
    appName: "ntfy HAOS Admin Panel",
    version: "0.2.0",
    ntfyBaseUrl: env.NTFY_BASE_URL,
    defaultTopics: DEFAULT_TOPICS,
    allowOverride: env.ALLOW_LOGIN_OVERRIDE,
    defaultAuthType: env.NTFY_AUTH_TYPE,
    session: s
      ? { username: s.username, authType: s.authType, expiresAt: new Date(s.exp * 1000).toISOString() }
      : null
  });
});
