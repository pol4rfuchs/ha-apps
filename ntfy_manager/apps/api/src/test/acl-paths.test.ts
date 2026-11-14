// Pins the ntfy paths used for access rules. ntfy has no /v1/access: it reads
// "access" as a topic name and answers 400 "topic name is not allowed". The
// real endpoint is /v1/users/access.
import assert from "node:assert/strict";
import http from "node:http";
import type { AddressInfo } from "node:net";
import { after, before, describe, it } from "node:test";

type Seen = { method: string; url: string; body: string };
const seen: Seen[] = [];
let mock: http.Server;
let api: http.Server;
let apiBase = "";

before(async () => {
  mock = http.createServer((req, res) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      seen.push({ method: req.method ?? "", url: req.url ?? "", body });
      // behave like ntfy: only /v1/users/access is a valid access endpoint
      const ok = req.url === "/v1/users/access";
      res.statusCode = ok ? 200 : 400;
      res.setHeader("content-type", "application/json");
      res.end(ok ? '{"success":true}' : '{"code":40010,"error":"invalid request: topic name is not allowed"}');
    });
  });
  await new Promise<void>((r) => mock.listen(0, "127.0.0.1", r));
  process.env.NTFY_BASE_URL = `http://127.0.0.1:${(mock.address() as AddressInfo).port}`;
  process.env.NTFY_AUTH_TYPE = "none";
  process.env.JWT_SECRET = "x".repeat(32);
  process.env.LOG_LEVEL = "error";

  const { default: express } = await import("express");
  const { ntfyRouter } = await import("../routes/ntfy.js");
  const app = express();
  app.use(express.json());
  // requireAuth accepts anonymous sessions when NTFY_AUTH_TYPE=none and the
  // request arrives via the Ingress peer address
  app.use((req, _res, next) => {
    req.headers["x-real-ip"] = "127.0.0.1";
    next();
  });
  app.use("/api/ntfy", ntfyRouter);
  api = http.createServer(app);
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  apiBase = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
});

after(() => {
  api.close();
  mock.close();
});

describe("access rules use /v1/users/access", () => {
  it("POST sets a rule", async () => {
    seen.length = 0;
    const r = await fetch(`${apiBase}/api/ntfy/access`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ username: "alice", topic: "alerts", permission: "read-write" })
    });
    assert.equal(r.status, 200);
    assert.equal(seen.length, 1);
    assert.equal(seen[0].method, "POST");
    assert.equal(seen[0].url, "/v1/users/access");
    assert.deepEqual(JSON.parse(seen[0].body), { username: "alice", topic: "alerts", permission: "read-write" });
  });

  it("DELETE removes a rule", async () => {
    seen.length = 0;
    const r = await fetch(`${apiBase}/api/ntfy/access`, {
      method: "DELETE",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ username: "alice", topic: "alerts" })
    });
    assert.equal(r.status, 200);
    assert.equal(seen[0].method, "DELETE");
    assert.equal(seen[0].url, "/v1/users/access");
    assert.deepEqual(JSON.parse(seen[0].body), { username: "alice", topic: "alerts" });
  });
});
