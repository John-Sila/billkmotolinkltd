import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker, { normalizePhone, verifyFirebaseToken, eatTimestamp } from "../src/index.js";

const PROJECT = "daitom";
const SCHEMA = readFileSync(new URL("../schema.sql", import.meta.url), "utf8");

// ---- fake D1 on top of node:sqlite -------------------------------------
function fakeD1() {
  const db = new DatabaseSync(":memory:");
  db.exec(SCHEMA);
  return {
    raw: db,
    prepare(sql) {
      return {
        bind: (...args) => ({
          first: async () => db.prepare(sql).get(...args) ?? null,
          run: async () => ({ meta: { changes: Number(db.prepare(sql).run(...args).changes) } }),
        }),
      };
    },
  };
}

// ---- Firebase token factory --------------------------------------------
const b64u = (buf) => Buffer.from(buf).toString("base64url");
const keyPair = await crypto.subtle.generateKey(
  { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
  true,
  ["sign", "verify"],
);
const publicJwk = { ...(await crypto.subtle.exportKey("jwk", keyPair.publicKey)), kid: "test-kid", alg: "RS256", use: "sig" };

async function makeToken({ uid = "rider-1", aud = PROJECT, expIn = 3600, kid = "test-kid", tamper = false } = {}) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64u(JSON.stringify({ alg: "RS256", kid, typ: "JWT" }));
  const payload = b64u(JSON.stringify({ sub: uid, aud, iss: `https://securetoken.google.com/${PROJECT}`, iat: now - 5, exp: now + expIn }));
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", keyPair.privateKey, new TextEncoder().encode(`${header}.${payload}`));
  const token = `${header}.${payload}.${b64u(sig)}`;
  return tamper ? token.slice(0, -4) + "AAAA" : token;
}

// ---- mocked network (Google keys + Safaricom) ----------------------------
let calls, queryReply, pushReply;
globalThis.fetch = async (url, opts = {}) => {
  url = String(url);
  calls.push({ url, body: opts.body ? JSON.parse(opts.body) : null });
  const ok = (data, status = 200) => new Response(JSON.stringify(data), { status });
  if (url.includes("googleapis.com/service_accounts")) return ok({ keys: [publicJwk] });
  if (url.includes("/oauth/v1/generate")) return ok({ access_token: "daraja-token", expires_in: "3599" });
  if (url.includes("/stkpush/v1/processrequest")) return pushReply();
  if (url.includes("/stkpushquery/v1/query")) return queryReply();
  throw new Error("unexpected fetch " + url);
};

let n = 0;
const okPush = () => {
  n += 1;
  return new Response(JSON.stringify({ MerchantRequestID: `m-${n}`, CheckoutRequestID: `ws_CO_${n}`, ResponseCode: "0", ResponseDescription: "Success", CustomerMessage: "Success" }));
};

let env;
beforeEach(() => {
  calls = [];
  pushReply = okPush;
  queryReply = () => new Response(JSON.stringify({ errorCode: "500.001.1001", errorMessage: "The transaction is being processed" }), { status: 500 });
  env = {
    DB: fakeD1(),
    FIREBASE_PROJECT_ID: PROJECT,
    MPESA_ENV: "production",
    MPESA_CONSUMER_KEY: "ck", MPESA_CONSUMER_SECRET: "cs", MPESA_PASSKEY: "passkey",
    MPESA_CALLBACK_SECRET: "s3cret",
    MPESA_SHORTCODE: "123456", MPESA_ACCOUNT_REF: "DAITOM01", MPESA_TXN_TYPE: "CustomerPayBillOnline",
    MAX_AMOUNT: "50000",
  };
});

const call = async (method, path, { token, body } = {}) => {
  const headers = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await worker.fetch(new Request(`https://pay.example.workers.dev${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined }), env);
  return { status: res.status, data: await res.json() };
};
const callbackBody = (id, code = 0, extra = {}) => ({
  Body: { stkCallback: { MerchantRequestID: "m", CheckoutRequestID: id, ResultCode: code, ResultDesc: code === 0 ? "The service request is processed successfully." : "Request cancelled by user",
    ...(code === 0 ? { CallbackMetadata: { Item: [
      { Name: "Amount", Value: extra.amount ?? 1250 }, { Name: "MpesaReceiptNumber", Value: extra.receipt ?? "SJK4XYZ123" },
      { Name: "TransactionDate", Value: 20260101120000 }, { Name: "PhoneNumber", Value: 254712345678 } ] } } : {}) } },
});

// ------------------------------------------------------------------ tests

test("normalizePhone accepts local and international formats", () => {
  for (const p of ["0712345678", "0712 345 678", "+254712345678", "254712345678", "712345678", "0112345678", "254112345678"]) {
    assert.match(normalizePhone(p), /^254[17]\d{8}$/, p);
  }
  for (const p of ["", "123", "0812345678", "07123456789", "abcdefghij", null, undefined]) assert.equal(normalizePhone(p), null, String(p));
  assert.equal(normalizePhone("0712345678"), "254712345678");
});

test("eatTimestamp is 14 digits and East Africa time", () => {
  assert.equal(eatTimestamp(new Date("2026-01-01T21:30:05Z")), "20260102003005");
});

test("verifyFirebaseToken: accepts a good token, rejects bad ones", async () => {
  assert.equal(await verifyFirebaseToken(await makeToken({ uid: "abc" }), PROJECT), "abc");
  await assert.rejects(verifyFirebaseToken(await makeToken({ expIn: -10 }), PROJECT), { status: 401 });
  await assert.rejects(verifyFirebaseToken(await makeToken({ aud: "other-project" }), PROJECT), { status: 401 });
  await assert.rejects(verifyFirebaseToken(await makeToken({ tamper: true }), PROJECT), { status: 401 });
  await assert.rejects(verifyFirebaseToken(await makeToken({ kid: "unknown" }), PROJECT), { status: 401 });
  await assert.rejects(verifyFirebaseToken("not.a.jwt", PROJECT), { status: 401 });
  await assert.rejects(verifyFirebaseToken("", PROJECT), { status: 401 });
});

test("requests without a valid sign-in are refused", async () => {
  assert.equal((await call("POST", "/pay", { body: { amount: 100, phone: "0712345678" } })).status, 401);
  assert.equal((await call("POST", "/pay", { token: await makeToken({ tamper: true }), body: { amount: 100, phone: "0712345678" } })).status, 401);
  assert.equal(calls.filter((c) => c.url.includes("safaricom")).length, 0, "Safaricom must not be contacted");
});

test("validates amount and phone before contacting Safaricom", async () => {
  const token = await makeToken();
  for (const amount of [0, -5, 12.5, "abc", 50001, null]) {
    assert.equal((await call("POST", "/pay", { token, body: { amount, phone: "0712345678" } })).status, 400, String(amount));
  }
  assert.equal((await call("POST", "/pay", { token, body: { amount: 100, phone: "12345" } })).status, 400);
  assert.equal(calls.filter((c) => c.url.includes("safaricom")).length, 0);
});

test("full flow: prompt -> callback -> status -> consume", async () => {
  const token = await makeToken({ uid: "rider-1" });

  const start = await call("POST", "/pay", { token, body: { amount: 1250, phone: "0712 345 678" } });
  assert.equal(start.status, 201);
  assert.equal(start.data.status, "pending");
  const id = start.data.checkoutId;

  // What was sent to Safaricom: paybill + account number flow, exact amount, normalised phone, secret callback path
  const push = calls.find((c) => c.url.includes("processrequest")).body;
  assert.equal(push.TransactionType, "CustomerPayBillOnline");
  assert.equal(push.BusinessShortCode, "123456");
  assert.equal(push.PartyB, "123456"); // paybill: PartyB == shortcode
  assert.equal(push.AccountReference, "DAITOM01");
  assert.equal(push.Amount, 1250);
  assert.equal(push.PartyA, "254712345678");
  assert.equal(push.CallBackURL, "https://pay.example.workers.dev/cb/s3cret");
  assert.equal(push.Password, btoa(`123456passkey${push.Timestamp}`));
  assert.doesNotMatch(push.CallBackURL, /mpesa|safaricom/i);

  // still pending, and too early to ask Safaricom
  assert.equal((await call("GET", `/pay/${id}`, { token })).data.status, "pending");
  assert.equal(calls.filter((c) => c.url.includes("stkpushquery")).length, 0);

  // Safaricom callback with the wrong secret is rejected
  assert.equal((await call("POST", "/cb/wrong", { body: callbackBody(id) })).status, 403);
  assert.equal((await call("GET", `/pay/${id}`, { token })).data.status, "pending");

  // real callback
  const cb = await call("POST", "/cb/s3cret", { body: callbackBody(id) });
  assert.deepEqual(cb.data, { ResultCode: 0, ResultDesc: "Accepted" });

  const done = (await call("GET", `/pay/${id}`, { token })).data;
  assert.equal(done.status, "paid");
  assert.equal(done.receipt, "SJK4XYZ123");
  assert.equal(done.paidAmount, 1250);

  // replayed callback does not change anything
  await call("POST", "/cb/s3cret", { body: callbackBody(id, 0, { receipt: "OTHER00000", amount: 1 }) });
  const again = (await call("GET", `/pay/${id}`, { token })).data;
  assert.equal(again.receipt, "SJK4XYZ123");
  assert.equal(again.paidAmount, 1250);

  // consume once
  assert.equal((await call("POST", `/pay/${id}/consume`, { token })).data.consumed, true);
  assert.equal((await call("POST", `/pay/${id}/consume`, { token })).data.consumed, false);

  // after consuming, the same amount requires a brand-new prompt
  const next = await call("POST", "/pay", { token, body: { amount: 1250, phone: "0712345678" } });
  assert.notEqual(next.data.checkoutId, id);
});

test("a rider cannot read or consume someone else's payment", async () => {
  const a = await makeToken({ uid: "rider-a" });
  const b = await makeToken({ uid: "rider-b" });
  const id = (await call("POST", "/pay", { token: a, body: { amount: 500, phone: "0712345678" } })).data.checkoutId;
  await call("POST", "/cb/s3cret", { body: callbackBody(id, 0, { amount: 500 }) });
  assert.equal((await call("GET", `/pay/${id}`, { token: b })).status, 404);
  assert.equal((await call("POST", `/pay/${id}/consume`, { token: b })).data.consumed, false);
  assert.equal((await call("GET", `/pay/${id}`, { token: a })).data.status, "paid");
});

test("double tap and paid-but-unfinished clock-outs never charge twice", async () => {
  const token = await makeToken();
  const first = await call("POST", "/pay", { token, body: { amount: 800, phone: "0712345678" } });
  const second = await call("POST", "/pay", { token, body: { amount: 800, phone: "0712345678" } });
  assert.equal(second.data.checkoutId, first.data.checkoutId);
  assert.equal(calls.filter((c) => c.url.includes("processrequest")).length, 1);

  await call("POST", "/cb/s3cret", { body: callbackBody(first.data.checkoutId, 0, { amount: 800 }) });
  const resumed = await call("POST", "/pay", { token, body: { amount: 800, phone: "0712345678" } });
  assert.equal(resumed.data.checkoutId, first.data.checkoutId);
  assert.equal(resumed.data.status, "paid");
  assert.equal(calls.filter((c) => c.url.includes("processrequest")).length, 1);
});

test("cancelled and failed prompts are reported, and can be retried", async () => {
  const token = await makeToken();
  const id = (await call("POST", "/pay", { token, body: { amount: 300, phone: "0712345678" } })).data.checkoutId;
  await call("POST", "/cb/s3cret", { body: callbackBody(id, 1032) });
  const r = (await call("GET", `/pay/${id}`, { token })).data;
  assert.equal(r.status, "cancelled");
  assert.equal(r.receipt, null);

  // a later "success" callback must not resurrect a cancelled prompt
  await call("POST", "/cb/s3cret", { body: callbackBody(id, 0, { amount: 300 }) });
  assert.equal((await call("GET", `/pay/${id}`, { token })).data.status, "cancelled");

  const retry = await call("POST", "/pay", { token, body: { amount: 300, phone: "0712345678" } });
  assert.equal(retry.status, 201);
  assert.notEqual(retry.data.checkoutId, id);
});

test("lost callback: status falls back to asking Safaricom", async () => {
  const token = await makeToken();
  const id = (await call("POST", "/pay", { token, body: { amount: 700, phone: "0712345678" } })).data.checkoutId;
  env.DB.raw.prepare("UPDATE payments SET created_at = created_at - 60000, updated_at = updated_at - 60000").run();

  // rider still entering PIN -> stays pending
  assert.equal((await call("GET", `/pay/${id}`, { token })).data.status, "pending");
  env.DB.raw.prepare("UPDATE payments SET updated_at = updated_at - 60000").run();

  // Safaricom now says it succeeded
  queryReply = () => new Response(JSON.stringify({ ResponseCode: "0", ResultCode: "0", ResultDesc: "The service request is processed successfully." }));
  const r = (await call("GET", `/pay/${id}`, { token })).data;
  assert.equal(r.status, "paid");

  // the late callback then fills in the receipt
  await call("POST", "/cb/s3cret", { body: callbackBody(id, 0, { amount: 700, receipt: "LATE123456" }) });
  assert.equal((await call("GET", `/pay/${id}`, { token })).data.receipt, "LATE123456");
});

test("Safaricom rejecting the prompt surfaces an error and records nothing", async () => {
  pushReply = () => new Response(JSON.stringify({ errorCode: "400.002.02", errorMessage: "Bad Request - Invalid PhoneNumber" }), { status: 400 });
  const res = await call("POST", "/pay", { token: await makeToken(), body: { amount: 100, phone: "0712345678" } });
  assert.equal(res.status, 502);
  assert.equal(env.DB.raw.prepare("SELECT COUNT(*) c FROM payments").get().c, 0);
});

test("attempt limit per rider per hour", async () => {
  const token = await makeToken();
  for (let i = 1; i <= 10; i++) {
    const r = await call("POST", "/pay", { token, body: { amount: 100 + i, phone: "0712345678" } });
    assert.equal(r.status, 201, `attempt ${i}`);
  }
  assert.equal((await call("POST", "/pay", { token, body: { amount: 999, phone: "0712345678" } })).status, 429);
});

test("unconfigured worker fails safe", async () => {
  delete env.MPESA_PASSKEY;
  const res = await call("POST", "/pay", { token: await makeToken(), body: { amount: 100, phone: "0712345678" } });
  assert.equal(res.status, 500);
  assert.equal(calls.filter((c) => c.url.includes("processrequest")).length, 0);
});
