import express from "express";
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

const app = express();

app.disable("x-powered-by");
app.use(
  helmet({
    contentSecurityPolicy: false,        // SPA handles its own headers via nginx
    crossOriginResourcePolicy: false     // We're served same-origin from nginx
  })
);
app.use(cors({ origin: false, credentials: true })); // same-origin only
app.use(express.json({ limit: "1mb" }));
app.use(cookieParser());
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
  logger.error(`Unhandled: ${err?.message ?? err}`);
  if (!res.headersSent) res.status(500).json({ error: "internal_error" });
});

app.listen(env.API_PORT, () => {
  audit("INFO", "runtime", `API started on port ${env.API_PORT}`);
  logger.info(`API listening on ${env.API_PORT} (ntfy at ${env.NTFY_BASE_URL})`);
});
