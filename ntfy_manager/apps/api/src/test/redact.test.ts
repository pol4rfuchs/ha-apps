import { test } from "node:test";
import assert from "node:assert/strict";

process.env.JWT_SECRET ??= "x".repeat(32);
process.env.NTFY_BASE_URL ??= "http://localhost";

const { redactCredentials } = await import("../services/logger.js");

test("redactCredentials strips userinfo from URLs", () => {
  assert.equal(
    redactCredentials("fetch failed: https://user:pw@ntfy.example/v1/x"),
    "fetch failed: https://ntfy.example/v1/x"
  );
});

test("redactCredentials leaves plain text and credential-free URLs alone", () => {
  assert.equal(redactCredentials("Timed out at http://ntfy:80/a@b"), "Timed out at http://ntfy:80/a@b");
});
