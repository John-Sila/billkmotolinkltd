// daitom-pay: sends the M-Pesa PIN prompt (STK push) at clock-out and keeps a
// ledger of what was really paid. Runs on Cloudflare Workers (free plan) + D1.
//
//   POST /pay                  rider asks for a prompt   -> { checkoutId, status, ... }
//   GET  /pay/:checkoutId      app polls for the result  -> { status, receipt, ... }
//   POST /pay/:checkoutId/consume   app marks a payment as used by a clock-out
//   POST /cb/:secret           Safaricom's result callback (not called by the app)
//
// The Daraja keys live here as Worker secrets and never touch the app.

const DARAJA = {
  sandbox: "https://sandbox.safaricom.co.ke",
  production: "https://api.safaricom.co.ke",
};
const JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

const PENDING_REUSE_MS = 90 * 1000;       // a prompt this young is still on the rider's phone
const UNCLAIMED_PAID_MS = 30 * 60 * 1000; // a paid-but-unused payment can be picked back up
const STATUS_MIN_AGE_MS = 20 * 1000;      // don't ask Safaricom before the rider could have paid
const STATUS_MIN_GAP_MS = 10 * 1000;      // ...and not more than once per 10 s
const MAX_ATTEMPTS_PER_HOUR = 10;

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

// ---------------------------------------------------------------- helpers

/** 0712 345 678 / +254712345678 / 254112345678 -> 2547XXXXXXXX, or null. */
export function normalizePhone(input) {
  const digits = String(input ?? "").replace(/[\s\-()]/g, "").replace(/^\+/, "");
  const m = /^(?:254|0)?([17]\d{8})$/.exec(digits);
  return m ? "254" + m[1] : null;
}

const b64urlToBytes = (s) =>
  Uint8Array.from(
    atob(s.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(s.length / 4) * 4, "=")),
    (c) => c.charCodeAt(0),
  );
const decodeJson = (s) => JSON.parse(new TextDecoder().decode(b64urlToBytes(s)));

function safeEqual(a, b) {
  a = String(a);
  b = String(b);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// ------------------------------------------------- Firebase ID-token check

let jwksCache = { keys: null, exp: 0 };
async function getJwks(force = false) {
  if (!force && jwksCache.keys && Date.now() < jwksCache.exp) return jwksCache.keys;
  const res = await fetch(JWKS_URL);
  if (!res.ok) throw new HttpError(503, "Could not load Google signing keys");
  const { keys } = await res.json();
  jwksCache = { keys, exp: Date.now() + 60 * 60 * 1000 };
  return keys;
}

/** Verifies a Firebase Auth ID token and returns the rider's uid. */
export async function verifyFirebaseToken(token, projectId) {
  const bad = () => new HttpError(401, "Please sign in again");
  const parts = String(token || "").split(".");
  if (parts.length !== 3) throw bad();

  let header, payload;
  try {
    header = decodeJson(parts[0]);
    payload = decodeJson(parts[1]);
  } catch {
    throw bad();
  }

  const now = Math.floor(Date.now() / 1000);
  if (header.alg !== "RS256" || !header.kid) throw bad();
  if (payload.aud !== projectId) throw bad();
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw bad();
  if (!payload.sub || typeof payload.exp !== "number" || payload.exp <= now) throw bad();
  if (typeof payload.iat === "number" && payload.iat > now + 300) throw bad();

  let jwk = (await getJwks()).find((k) => k.kid === header.kid);
  if (!jwk) jwk = (await getJwks(true)).find((k) => k.kid === header.kid);
  if (!jwk) throw bad();

  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    b64urlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) throw bad();
  return payload.sub;
}

async function authenticate(req, env) {
  const m = /^Bearer (.+)$/.exec(req.headers.get("authorization") || "");
  if (!m) throw new HttpError(401, "Please sign in again");
  return verifyFirebaseToken(m[1], env.FIREBASE_PROJECT_ID);
}

// ------------------------------------------------------------------ Daraja

let tokenCache = { key: "", token: null, exp: 0 };

function requireConfig(env) {
  const need = [
    "MPESA_CONSUMER_KEY", "MPESA_CONSUMER_SECRET", "MPESA_PASSKEY", "MPESA_CALLBACK_SECRET",
    "MPESA_SHORTCODE", "MPESA_ACCOUNT_REF", "MPESA_TXN_TYPE", "FIREBASE_PROJECT_ID",
  ];
  const missing = need.filter((k) => !env[k]);
  if (missing.length || !env.DB) {
    console.error("Worker not configured, missing:", missing.join(", ") || "DB binding");
    throw new HttpError(500, "Payments are not set up on the server yet");
  }
}

const darajaBase = (env) => (env.MPESA_ENV === "production" ? DARAJA.production : DARAJA.sandbox);

async function darajaToken(env) {
  const cacheKey = `${env.MPESA_ENV}:${env.MPESA_CONSUMER_KEY}`;
  if (tokenCache.key === cacheKey && tokenCache.token && Date.now() < tokenCache.exp) {
    return tokenCache.token;
  }
  const res = await fetch(`${darajaBase(env)}/oauth/v1/generate?grant_type=client_credentials`, {
    headers: { authorization: "Basic " + btoa(`${env.MPESA_CONSUMER_KEY}:${env.MPESA_CONSUMER_SECRET}`) },
  });
  if (!res.ok) {
    console.error("Daraja auth failed", res.status, await res.text());
    throw new HttpError(502, "M-Pesa is unavailable right now");
  }
  const data = await res.json();
  tokenCache = {
    key: cacheKey,
    token: data.access_token,
    exp: Date.now() + (Number(data.expires_in || 3599) - 120) * 1000,
  };
  return data.access_token;
}

/** YYYYMMDDHHmmss in East Africa Time. */
export function eatTimestamp(d = new Date()) {
  return new Date(d.getTime() + 3 * 3600 * 1000).toISOString().replace(/[-:T]/g, "").slice(0, 14);
}

const stkPassword = (env, ts) => btoa(`${env.MPESA_SHORTCODE}${env.MPESA_PASSKEY}${ts}`);

async function stkPush(env, { amount, phone, callbackUrl }) {
  const ts = eatTimestamp();
  const res = await fetch(`${darajaBase(env)}/mpesa/stkpush/v1/processrequest`, {
    method: "POST",
    headers: { authorization: `Bearer ${await darajaToken(env)}`, "content-type": "application/json" },
    body: JSON.stringify({
      BusinessShortCode: env.MPESA_SHORTCODE,
      Password: stkPassword(env, ts),
      Timestamp: ts,
      TransactionType: env.MPESA_TXN_TYPE,
      Amount: amount,
      PartyA: phone,
      // Paybill: PartyB is the paybill itself (same as BusinessShortCode).
      // MPESA_TILL is only used if you ever switch back to Buy Goods.
      PartyB: env.MPESA_TILL || env.MPESA_SHORTCODE,
      PhoneNumber: phone,
      CallBackURL: callbackUrl,
      // Shown to the rider on the PIN prompt and on the M-Pesa SMS as the Account No.
      AccountReference: String(env.MPESA_ACCOUNT_REF).slice(0, 12),
      TransactionDesc: "DAITOM shift payment",
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || String(data.ResponseCode) !== "0" || !data.CheckoutRequestID) {
    console.error("STK push rejected", res.status, JSON.stringify(data));
    throw new HttpError(502, data.errorMessage || data.ResponseDescription || "Could not send the M-Pesa prompt");
  }
  return { checkoutId: data.CheckoutRequestID, merchantRequestId: data.MerchantRequestID || null };
}

/** Asks Safaricom directly. Returns {done:false} while the rider is still deciding. */
async function stkQuery(env, checkoutId) {
  const ts = eatTimestamp();
  const res = await fetch(`${darajaBase(env)}/mpesa/stkpushquery/v1/query`, {
    method: "POST",
    headers: { authorization: `Bearer ${await darajaToken(env)}`, "content-type": "application/json" },
    body: JSON.stringify({
      BusinessShortCode: env.MPESA_SHORTCODE,
      Password: stkPassword(env, ts),
      Timestamp: ts,
      CheckoutRequestID: checkoutId,
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (data.ResultCode === undefined || data.ResultCode === null) return { done: false }; // "being processed"
  return { done: true, code: Number(data.ResultCode), desc: data.ResultDesc || "" };
}

// ---------------------------------------------------------------- database

const view = (r) => ({
  checkoutId: r.checkout_id,
  status: r.status,
  amount: r.amount,
  receipt: r.receipt ?? null,
  paidAmount: r.paid_amount ?? null,
  message: r.result_desc ?? null,
  createdAt: r.created_at,
});

const getRow = (env, id) =>
  env.DB.prepare("SELECT * FROM payments WHERE checkout_id = ?").bind(id).first();

function statusFor(code) {
  if (code === 0) return "paid";
  if (code === 1032) return "cancelled"; // rider dismissed the prompt
  return "failed";
}

// ---------------------------------------------------------------- handlers

async function handlePay(req, env) {
  const uid = await authenticate(req, env);
  requireConfig(env);

  let body;
  try {
    body = await req.json();
  } catch {
    throw new HttpError(400, "Invalid request");
  }
  const amount = Number(body?.amount);
  const max = Number(env.MAX_AMOUNT || 50000);
  if (!Number.isInteger(amount) || amount < 1 || amount > max) {
    throw new HttpError(400, `Amount must be a whole number between 1 and ${max}`);
  }
  const phone = normalizePhone(body?.phone);
  if (!phone) throw new HttpError(400, "Enter a valid Safaricom number, e.g. 0712 345 678");

  const now = Date.now();

  // Double-tap, app restart, or a payment that went through but the clock-out
  // didn't finish: hand back the existing payment instead of charging twice.
  const existing = await env.DB.prepare(
    `SELECT * FROM payments
      WHERE uid = ? AND consumed_at IS NULL AND amount = ? AND created_at > ?
        AND (status = 'paid' OR (status = 'pending' AND created_at > ?))
      ORDER BY created_at DESC LIMIT 1`,
  )
    .bind(uid, amount, now - UNCLAIMED_PAID_MS, now - PENDING_REUSE_MS)
    .first();
  if (existing) return json(view(existing));

  const attempts = await env.DB.prepare(
    "SELECT COUNT(*) AS c FROM payments WHERE uid = ? AND created_at > ?",
  )
    .bind(uid, now - 3600 * 1000)
    .first();
  if ((attempts?.c ?? 0) >= MAX_ATTEMPTS_PER_HOUR) {
    throw new HttpError(429, "Too many attempts. Please wait a few minutes and try again.");
  }

  const callbackUrl = `${new URL(req.url).origin}/cb/${env.MPESA_CALLBACK_SECRET}`;
  const { checkoutId, merchantRequestId } = await stkPush(env, { amount, phone, callbackUrl });

  await env.DB.prepare(
    `INSERT INTO payments (checkout_id, merchant_request_id, uid, phone, amount, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)`,
  )
    .bind(checkoutId, merchantRequestId, uid, phone, amount, now, now)
    .run();

  return json(view(await getRow(env, checkoutId)), 201);
}

async function handleStatus(req, env, checkoutId) {
  const uid = await authenticate(req, env);
  requireConfig(env);

  let row = await getRow(env, checkoutId);
  if (!row || row.uid !== uid) throw new HttpError(404, "Payment not found");

  // The callback normally settles this. If it's late or lost, ask Safaricom.
  const now = Date.now();
  if (row.status === "pending" && now - row.created_at > STATUS_MIN_AGE_MS && now - row.updated_at > STATUS_MIN_GAP_MS) {
    const q = await stkQuery(env, checkoutId).catch((e) => {
      console.error("STK query failed", e);
      return { done: false };
    });
    if (q.done) {
      await env.DB.prepare(
        `UPDATE payments SET status = ?, result_code = ?, result_desc = ?, updated_at = ?
          WHERE checkout_id = ? AND status = 'pending'`,
      )
        .bind(statusFor(q.code), q.code, q.desc, now, checkoutId)
        .run();
    } else {
      await env.DB.prepare("UPDATE payments SET updated_at = ? WHERE checkout_id = ? AND status = 'pending'")
        .bind(now, checkoutId)
        .run();
    }
    row = await getRow(env, checkoutId);
  }
  return json(view(row));
}

async function handleConsume(req, env, checkoutId) {
  const uid = await authenticate(req, env);
  requireConfig(env);
  const res = await env.DB.prepare(
    `UPDATE payments SET consumed_at = ?
      WHERE checkout_id = ? AND uid = ? AND status = 'paid' AND consumed_at IS NULL`,
  )
    .bind(Date.now(), checkoutId, uid)
    .run();
  const changed = res?.meta?.changes ?? 0;
  return json({ ok: true, consumed: changed > 0 });
}

async function handleCallback(req, env, secret) {
  requireConfig(env);
  if (!safeEqual(secret, env.MPESA_CALLBACK_SECRET)) throw new HttpError(403, "Forbidden");

  const ack = () => json({ ResultCode: 0, ResultDesc: "Accepted" });
  let cb;
  try {
    cb = (await req.json())?.Body?.stkCallback;
  } catch {
    return ack();
  }
  if (!cb?.CheckoutRequestID) return ack();

  const row = await getRow(env, cb.CheckoutRequestID);
  if (!row) return ack(); // not one of ours

  const code = Number(cb.ResultCode);
  const now = Date.now();

  if (code === 0) {
    const items = Object.fromEntries((cb.CallbackMetadata?.Item ?? []).map((i) => [i.Name, i.Value]));
    await env.DB.prepare(
      `UPDATE payments
          SET status = 'paid',
              receipt = COALESCE(receipt, ?),
              paid_amount = COALESCE(paid_amount, ?),
              paid_phone = COALESCE(paid_phone, ?),
              result_code = 0, result_desc = ?, updated_at = ?
        WHERE checkout_id = ? AND status IN ('pending', 'paid')`,
    )
      .bind(
        items.MpesaReceiptNumber ?? null,
        items.Amount != null ? Math.round(Number(items.Amount)) : null,
        items.PhoneNumber != null ? String(items.PhoneNumber) : null,
        cb.ResultDesc ?? "",
        now,
        cb.CheckoutRequestID,
      )
      .run();
  } else {
    await env.DB.prepare(
      `UPDATE payments SET status = ?, result_code = ?, result_desc = ?, updated_at = ?
        WHERE checkout_id = ? AND status = 'pending'`,
    )
      .bind(statusFor(code), code, cb.ResultDesc ?? "", now, cb.CheckoutRequestID)
      .run();
  }
  return ack();
}

// ------------------------------------------------------------------ router

export default {
  async fetch(req, env) {
    const { pathname } = new URL(req.url);
    try {
      let m;
      if (pathname === "/" && req.method === "GET") return json({ ok: true, service: "daitom-pay" });
      if (pathname === "/pay" && req.method === "POST") return await handlePay(req, env);
      if ((m = /^\/pay\/([^/]+)$/.exec(pathname)) && req.method === "GET") return await handleStatus(req, env, m[1]);
      if ((m = /^\/pay\/([^/]+)\/consume$/.exec(pathname)) && req.method === "POST") return await handleConsume(req, env, m[1]);
      if ((m = /^\/cb\/([^/]+)$/.exec(pathname)) && req.method === "POST") return await handleCallback(req, env, m[1]);
      throw new HttpError(404, "Not found");
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message }, e.status);
      console.error("Unhandled error", e);
      return json({ error: "Something went wrong" }, 500);
    }
  },
};
