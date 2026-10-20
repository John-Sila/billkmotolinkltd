// Checks that your Daraja SANDBOX app can send an M-Pesa Express (PIN prompt) request.
// Run it on your own computer - your keys are read from the terminal session and are
// never printed or sent anywhere except Safaricom's sandbox.
//
//   PowerShell:
//     $env:MPESA_CONSUMER_KEY="paste-key-here"
//     $env:MPESA_CONSUMER_SECRET="paste-secret-here"
//     $env:MPESA_PASSKEY="paste-passkey-here"
//     node scripts/sandbox-check.mjs
//
// (The values only exist in that terminal window until you close it.)

const key = process.env.MPESA_CONSUMER_KEY;
const secret = process.env.MPESA_CONSUMER_SECRET;
const passkey = process.env.MPESA_PASSKEY;

if (!key || !secret || !passkey) {
  console.log("Missing values. Set MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET and MPESA_PASSKEY first (see the top of this file).");
  process.exit(1);
}

const BASE = "https://sandbox.safaricom.co.ke";
const SHORTCODE = "174379"; // Safaricom sandbox test paybill
const show = (v) => (typeof v === "string" ? v : JSON.stringify(v));

// ---- 1. consumer key + secret -> access token
const tokenRes = await fetch(`${BASE}/oauth/v1/generate?grant_type=client_credentials`, {
  headers: { authorization: "Basic " + Buffer.from(`${key}:${secret}`).toString("base64") },
});
const tokenText = await tokenRes.text();
if (!tokenRes.ok) {
  console.log(`\n1) Access token: FAILED (HTTP ${tokenRes.status})`);
  console.log("   Safaricom said:", tokenText.slice(0, 300) || "(empty)");
  console.log("   -> The consumer key or secret is wrong, or has stray spaces. Re-copy them from your app page.");
  process.exit(1);
}
console.log("\n1) Access token: OK (consumer key and secret are valid)");
const token = JSON.parse(tokenText).access_token;

// ---- 2. send a test STK push (KES 1 to a sandbox number - no real money moves)
const d = new Date(Date.now() + 3 * 3600 * 1000);
const timestamp = d.toISOString().replace(/[-:T]/g, "").slice(0, 14);
const password = Buffer.from(`${SHORTCODE}${passkey}${timestamp}`).toString("base64");

const stkRes = await fetch(`${BASE}/mpesa/stkpush/v1/processrequest`, {
  method: "POST",
  headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  body: JSON.stringify({
    BusinessShortCode: SHORTCODE,
    Password: password,
    Timestamp: timestamp,
    TransactionType: "CustomerPayBillOnline",
    Amount: 1,
    PartyA: "254708374149",
    PartyB: SHORTCODE,
    PhoneNumber: "254708374149",
    CallBackURL: "https://example.com/cb",
    AccountReference: "TEST",
    TransactionDesc: "Sandbox check",
  }),
});
const stkText = await stkRes.text();
let stk = {};
try { stk = JSON.parse(stkText); } catch { /* not JSON */ }

console.log(`\n2) M-Pesa Express request: HTTP ${stkRes.status}`);
console.log("   Safaricom said:", stkText.slice(0, 400) || "(empty)");

if (String(stk.ResponseCode) === "0") {
  console.log("\nRESULT: WORKS. This sandbox app can send PIN prompts. Carry on with the secrets and deploy.");
} else if (/passkey|password|invalid.*(password|credentials)/i.test(show(stk.errorMessage ?? stk.ResponseDescription ?? ""))) {
  console.log("\nRESULT: The app can reach M-Pesa Express, but the PASSKEY looks wrong. Re-copy it from the Daraja Simulate page.");
} else if (stkRes.status === 401 || stkRes.status === 403 || /access token|not authori|forbidden|product/i.test(show(stk.errorMessage ?? stk.errorCode ?? stkText))) {
  console.log("\nRESULT: This app is probably NOT enabled for M-Pesa Express (the 'Lipa Na M-Pesa Sandbox' product).");
  console.log("        Try creating the app with that product again later, or ask Daraja support to map it to your app.");
} else {
  console.log("\nRESULT: Not clear. Send the 'Safaricom said' lines above to your helper (they contain no secrets).");
}
