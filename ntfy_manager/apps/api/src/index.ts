import express from "express";
import { ZodError } from "zod";
import cors from "cors";
import helmet from "helmet";
import cookieParser from "cookie-parser";
import morgan from "morgan";
import { env } from "./env.js";
import { authRouter } from "./routes/auth.js";
import { ntfyRouter } from "./routes/ntfy.js";
import { publishRouter } from "./routes/publish.js";
import { messagesRouter } from "./routes/messages.js";
import { streamRouter } from "./routes/stream.js";
import { logsRouter } from "./routes/logs.js";
import { configRouter } from "./routes/config.js";
import { audit, logger } from "./services/logger.js";
import { csrfGuard } from "./middleware/csrf.js";

const app = express();

app.disable("x-powered-by");
// nginx on loopback is the only proxy: take req.ip from the X-Forwarded-For
// entry it appends, so the login rate limit counts per client instead of
// treating every request as 127.0.0.1.
app.set("trust proxy", "loopback");
app.use(
  helmet({
    // CodeQL #234 (js/insecure-helmet-configuration): explicit CSP instead
    // of disabling it outright. Everything is same-origin (served by nginx
    // alongside the SPA), so 'self' covers scripts/connects/images; inline
    // styles stay allowed since React sets some styles via style props.
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        connectSrc: ["'self'"], // fetch + SSE stream, both same-origin
        imgSrc: ["'self'", "data:"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        baseUri: ["'self'"],
        frameAncestors: ["'self'"]
      }
    },
    crossOriginResourcePolicy: false // We're served same-origin from nginx
  })
);
app.use(cors({ origin: false, credentials: true })); // same-origin only
app.use(express.json({ limit: "1mb" }));
app.use(cookieParser());
// State-changing requests need the panel's own header and no cross-site origin
app.use(csrfGuard);
app.use(
  morgan("tiny", {
    skip: (req) => req.url.startsWith("/api/health") || req.url.startsWith("/api/ntfy/stream")
  })
);

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", app: "ntfy-haos-admin", version: "0.2.0" });
});

app.use("/api/config", configRouter);
app.use("/api/auth", authRouter);
app.use("/api/ntfy", ntfyRouter);
app.use("/api/ntfy/publish", publishRouter);
app.use("/api/ntfy/messages", messagesRouter);
app.use("/api/ntfy/stream", streamRouter);
app.use("/api/logs", logsRouter);

app.use((_req, res) => res.status(404).json({ error: "not_found" }));

// Final error guard
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  // Bad input from the client is a 400, not a server error: a body that fails
  // validation (zod) or is not valid JSON (body parser).
  if (err instanceof ZodError) {
    if (!res.headersSent) {
      res.status(400).json({
        error: "invalid_request",
        message: "Invalid request body.",
        issues: err.issues.map((i) => ({ path: i.path.join("."), message: i.message }))
      });
    }
    return;
  }
  if (err?.type === "entity.parse.failed" || err?.type === "entity.too.large") {
    if (!res.headersSent) {
      res.status(err.type === "entity.too.large" ? 413 : 400).json({ error: "invalid_request" });
    }
    return;
  }
  logger.error(`Unhandled: ${err?.message ?? err}`);
  if (!res.headersSent) res.status(500).json({ error: "internal_error" });
});

// Loopback only: nginx is the sole entry point and sets X-Real-IP, which the
// auth middleware relies on to tell Ingress from direct port access.
app.listen(env.API_PORT, "127.0.0.1", () => {
  audit("INFO", "runtime", `API started on port ${env.API_PORT}`);
  logger.info(`API listening on ${env.API_PORT} (ntfy at ${env.NTFY_BASE_URL})`);
});
