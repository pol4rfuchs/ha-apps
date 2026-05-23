import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { ntfyStream } from "../ntfy/client.js";
import { audit } from "../services/logger.js";

export const streamRouter = Router();

streamRouter.use(requireAuth);

/**
 * GET /api/ntfy/stream?topic=ha-alerts,ha-info
 *
 * Opens an SSE stream on ntfy upstream and pipes the byte stream straight to
 * the browser as text/event-stream.  We don't reformat events — ntfy already
 * emits standards-compliant SSE.
 */
streamRouter.get("/", async (req, res) => {
  const schema = z.object({
    topic: z.string().min(1)
  });

  let q;
  try {
    q = schema.parse(req.query);
  } catch (e) {
    res.status(400).json({ error: "invalid_query" });
    return;
  }

  const topics = q.topic
    .split(",")
    .map((t) => t.trim())
    .filter(Boolean);

  if (!topics.length) {
    res.status(400).json({ error: "no_topics" });
    return;
  }

  // SSE response headers (browser side)
  res.set({
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no"
  });
  res.flushHeaders?.();

  const ctrl = new AbortController();
  let closed = false;
  const cleanup = () => {
    if (closed) return;
    closed = true;
    ctrl.abort();
  };
  req.on("close", cleanup);
  req.on("aborted", cleanup);

  const upstreamPath = `/${topics.map(encodeURIComponent).join(",")}/sse`;

  audit("INFO", "stream", `SSE open ${topics.join(",")}`);

  let upstream: Response;
  try {
    upstream = await ntfyStream(upstreamPath, {
      session: req.session,
      signal: ctrl.signal
    });
  } catch (e) {
    if (!closed) {
      res.write(
        `event: error\ndata: ${JSON.stringify({
          message: e instanceof Error ? e.message : String(e)
        })}\n\n`
      );
      res.end();
    }
    return;
  }

  if (!upstream.ok) {
    res.write(
      `event: error\ndata: ${JSON.stringify({ status: upstream.status })}\n\n`
    );
    res.end();
    return;
  }

  if (!upstream.body) {
    res.write(`event: error\ndata: ${JSON.stringify({ message: "no_body" })}\n\n`);
    res.end();
    return;
  }

  const reader = upstream.body.getReader();
  const decoder = new TextDecoder();

  try {
    while (!closed) {
      const { value, done } = await reader.read();
      if (done) break;
      if (!value) continue;
      const chunk = decoder.decode(value, { stream: true });
      // Pipe upstream chunk directly — already SSE-formatted.
      if (!res.write(chunk)) {
        await new Promise<void>((r) => res.once("drain", () => r()));
      }
    }
  } catch (e) {
    if (!closed) {
      audit("WARN", "stream", `SSE error: ${e instanceof Error ? e.message : String(e)}`);
    }
  } finally {
    try {
      reader.releaseLock();
    } catch {
      /* noop */
    }
    if (!closed) res.end();
    audit("INFO", "stream", `SSE close ${topics.join(",")}`);
  }
});
