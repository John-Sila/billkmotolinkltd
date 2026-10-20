# daitom-pay

Sends the **M-Pesa PIN prompt** when a rider clocks out, and keeps a ledger of what was
really paid. Runs on Cloudflare's free plan (Workers + D1). No server to maintain.

```
Rider taps Confirm -> app asks this Worker for a prompt -> rider's phone shows the
M-Pesa PIN screen -> rider pays -> Safaricom tells the Worker -> app sees "paid" and
finishes the clock-out with the receipt attached.
```

The M-Pesa keys live **only** in the Worker (as secrets). The app never sees them, and
the app cannot say "paid" - only the Worker's ledger can.

## What you need

1. A free **Cloudflare** account - https://dash.cloudflare.com/sign-up (no card needed)
2. **Node.js** (18+) on your computer
3. A **Safaricom Daraja** account - https://developer.safaricom.co.ke
   - For testing: a sandbox app with "M-Pesa Express" enabled (free, instant)
   - For real money: your Paybill must be taken **live** on Daraja (see "Going live")

## Set up (about 15 minutes)

Run these inside this `payments_worker` folder.

1. `npm install`
2. `npx wrangler login` (opens a browser to link your Cloudflare account)
3. Run the tests - they use a pretend Safaricom: `npm test` (13 should pass)
4. `npx wrangler d1 create daitom-pay`
   It prints a `database_id`. **Paste it into `wrangler.toml`** (replace `PASTE-THE-ID-FROM-STEP-4`).
5. `npx wrangler d1 execute daitom-pay --remote --file=schema.sql`
6. Add the secrets. Each command asks you to paste the value:
   ```
   npx wrangler secret put MPESA_CONSUMER_KEY
   npx wrangler secret put MPESA_CONSUMER_SECRET
   npx wrangler secret put MPESA_PASSKEY
   npx wrangler secret put MPESA_CALLBACK_SECRET
   ```
   - The first three come from your Daraja app (sandbox page: *My Apps* -> your app; the
     passkey is on *APIs* -> *M-Pesa Express* -> *Simulate*).
   - `MPESA_CALLBACK_SECRET` is something **you invent**: a long random string, e.g. run
     `node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"`.
     It becomes part of the address Safaricom reports payments to, so keep it private.
7. `npx wrangler deploy`
   It prints your address, like `https://daitom-pay.YOUR-SUBDOMAIN.workers.dev`.
   Open it in a browser: you should see `{"ok":true,"service":"daitom-pay"}`.

## Connect the app

Open `lib/services/payment_config.dart` and paste your address:

```dart
const String kPaymentApiBase = 'https://daitom-pay.YOUR-SUBDOMAIN.workers.dev';
```

That is the only switch. Rebuild the app and every clock-out with money to remit will show the
M-Pesa PIN prompt. While the address is empty (`''`), clock-out behaves exactly as before.

**Test in the sandbox first.** The sandbox simulates M-Pesa: you will not get a real prompt on a
phone, but the request and the result come back through the same path, so you can confirm
the whole flow works before real money is involved.

## Going live (real Paybill)

1. In Daraja, use **Go Live** for the DAITOM **Paybill** and request **M-Pesa Express (STK Push)**.
   Safaricom gives you production credentials (consumer key, consumer secret, passkey).
2. In `wrangler.toml`, switch the `[vars]` to the production block:
   - `MPESA_ENV` = `"production"`
   - `MPESA_SHORTCODE` = your **Paybill number**
   - `MPESA_ACCOUNT_REF` = your **account number** (max 12 characters). This is what the rider
     sees as "Account" on the PIN prompt and on the M-Pesa confirmation SMS.
   - `MPESA_TXN_TYPE` = `"CustomerPayBillOnline"` (already set)
3. Replace the three Daraja secrets with the **production** ones (same `wrangler secret put` commands).
4. `npx wrangler deploy`

**What shows on the M-Pesa message.** The *business name* on the prompt and SMS (for example
"DAITOM MOTORLINK LTD") is the name Safaricom has registered against your Paybill. It is set by
Safaricom, not by the app. If the SMS shows a different name, ask Safaricom (Business Care /
your account manager) to update the registered name on the Paybill. The *account number* is
controlled here by `MPESA_ACCOUNT_REF`.

## Looking at the ledger

Cloudflare dashboard -> **Storage & Databases** -> **D1** -> `daitom-pay` -> **Console**, or:

```
npx wrangler d1 execute daitom-pay --remote --command "SELECT datetime(created_at/1000,'unixepoch','+3 hours') AS time, uid, phone, amount, status, receipt, paid_amount FROM payments ORDER BY created_at DESC LIMIT 50"
```

Every clock-out in Firestore also stores `payment.receipt` and `payment.checkoutId`, so a clock-out
with **no** receipt (or a receipt that is not in this ledger) is one to question.

## Good to know

- **No double charging.** If a rider taps twice, or pays but the app dies before finishing, the next
  attempt for the same amount picks up the existing payment (for 30 minutes) instead of sending a new prompt.
- **Lost callbacks are covered.** If Safaricom's report never arrives, the Worker asks Safaricom directly.
- **Limits.** Max 10 prompts per rider per hour, and `MAX_AMOUNT` per prompt (default KES 50,000).
- **What this does and doesn't prove.** It proves the rider paid *exactly the amount they reported*, through
  a real PIN entry. It does not check that the gross income they typed is true; that still needs the
  usual checks (daily target, in-app screenshots).
- **A hacked/modified app** could skip the prompt and write a clock-out with no receipt. It cannot fake a
  receipt that is in this ledger, which is why reviewing receipts matters. If you later want to *block*
  that too, the next step is having the Worker write the clock-out itself (needs a Firebase service account).
