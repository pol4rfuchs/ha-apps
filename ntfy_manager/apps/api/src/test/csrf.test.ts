import assert from "node:assert/strict";
import http from "node:http";
import type { AddressInfo } from "node:net";
import { after, before, describe, it } from "node:test";
import express from "express";
import { csrfGuard } from "../middleware/csrf.js";

let server: http.Server;
let base = "";

before(async () => {
  const app = express();
  app.use(csrfGuard);
  app.all("/x", (_req, res) => res.json({ ok: true }));
  server = http.createServer(app);
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}/x`;
});
after(() => server.close());

const send = (method: string, headers: Record<string, string> = {}) =>
  fetch(base, { method, headers }).then((r) => r.status);

describe("csrf guard", () => {
  it("lets safe methods through without a header", async () => {
    assert.equal(await send("GET"), 200);
  });
  it("refuses a state-changing request without the header", async () => {
    for (const m of ["POST", "PUT", "DELETE", "PATCH"]) assert.equal(await send(m), 403, m);
  });
  it("accepts the panel header", async () => {
    assert.equal(await send("POST", { "X-Requested-With": "ntfy-admin" }), 200);
  });
  it("refuses cross-site and same-site fetch metadata even with the header", async () => {
    for (const v of ["cross-site", "same-site"]) {
      assert.equal(await send("POST", { "X-Requested-With": "ntfy-admin", "Sec-Fetch-Site": v }), 403, v);
    }
  });
  it("accepts same-origin fetch metadata", async () => {
    assert.equal(await send("DELETE", { "X-Requested-With": "ntfy-admin", "Sec-Fetch-Site": "same-origin" }), 200);
  });
  it("refuses a wrong header value", async () => {
    assert.equal(await send("POST", { "X-Requested-With": "x" }), 403);
  });
});
