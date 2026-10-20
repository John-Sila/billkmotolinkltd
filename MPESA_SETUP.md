# DAITOM M-Pesa setup (Paybill + Account Number) - from zero

Nothing here is shared with any other app. You create: a Daraja account, a Cloudflare account,
one worker (daitom-pay) and one database (daitom-pay).

## 1. Daraja account (Safaricom)
1. https://developer.safaricom.co.ke -> Sign up with a DAITOM company email -> verify email -> log in.
2. My Apps -> Add a new app. Name: DAITOM Pay. Tick "M-Pesa Sandbox" and "Lipa Na M-Pesa Sandbox" (M-Pesa Express).
3. Open the app. Copy Consumer Key and Consumer Secret (sandbox).
4. APIs -> M-Pesa Express -> Simulate. Copy the sandbox Passkey and note test shortcode 174379.

## 2. Cloudflare account
1. https://dash.cloudflare.com/sign-up (free, no card). Verify email.
2. Install Node.js 18+ (22 recommended): https://nodejs.org

## 3. Deploy the worker (sandbox first)
    cd payments_worker
    npm install
    npx wrangler login
    npm test
    npx wrangler d1 create daitom-pay
(paste the printed database_id into wrangler.toml replacing PASTE-THE-ID-FROM-STEP-4)
    npx wrangler d1 execute daitom-pay --remote --file=schema.sql
    node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
    npx wrangler secret put MPESA_CONSUMER_KEY
    npx wrangler secret put MPESA_CONSUMER_SECRET
    npx wrangler secret put MPESA_PASSKEY
    npx wrangler secret put MPESA_CALLBACK_SECRET     (paste the random string)
    npx wrangler deploy
First deploy may ask you to pick a workers.dev subdomain. The address printed is
https://daitom-pay.<subdomain>.workers.dev - open it: {"ok":true,"service":"daitom-pay"}.

## 4. Connect the app
lib/services/payment_config.dart -> kPaymentApiBase = '<that address>';  then flutter run.
Test a clock-out. Sandbox gives a simulated prompt, not a real phone prompt.

## 5. Go live (real money) - needs Safaricom approval
1. You need a live DAITOM Paybill and its account number (from Safaricom / M-Pesa for Business).
2. Daraja -> your app -> Go Live. Provide Paybill, callback URL (your worker address + /cb/...; the worker builds it itself),
   settlement details and any documents asked. Request M-Pesa Express.
   Timeline varies from a few days to weeks.
3. Safaricom issues production Consumer Key, Secret and Passkey for your Paybill.
4. wrangler.toml: comment out the sandbox block and set
     MPESA_ENV = "production"
     MPESA_SHORTCODE = "<paybill>"
     MPESA_ACCOUNT_REF = "<account number, max 12 chars>"
     MPESA_TXN_TYPE = "CustomerPayBillOnline"
5. Re-run the three `wrangler secret put` commands with PRODUCTION values (callback secret can stay), then npx wrangler deploy.
6. Test with a small real amount, check the SMS, and check the ledger:
     npx wrangler d1 execute daitom-pay --remote --command "SELECT * FROM payments ORDER BY created_at DESC LIMIT 10"

The business name on the SMS is the name Safaricom registered for the Paybill; only Safaricom can change it.
