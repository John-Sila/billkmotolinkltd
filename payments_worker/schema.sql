-- Ledger of every M-Pesa prompt the app sends. This is the source of truth for
-- "what was actually paid" - the app only ever reads it, never writes it.
CREATE TABLE IF NOT EXISTS payments (
  checkout_id          TEXT PRIMARY KEY,           -- Safaricom CheckoutRequestID
  merchant_request_id  TEXT,
  uid                  TEXT NOT NULL,              -- Firebase uid of the rider
  phone                TEXT NOT NULL,              -- number the prompt was sent to (2547XXXXXXXX)
  amount               INTEGER NOT NULL,           -- KES requested
  status               TEXT NOT NULL DEFAULT 'pending',  -- pending | paid | failed | cancelled
  receipt              TEXT UNIQUE,                -- M-Pesa receipt code, e.g. SJK4XYZ123
  result_code          INTEGER,
  result_desc          TEXT,
  paid_amount          INTEGER,                    -- KES Safaricom says was actually paid
  paid_phone           TEXT,
  consumed_at          INTEGER,                    -- set once a clock-out has used this payment
  created_at           INTEGER NOT NULL,
  updated_at           INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_payments_uid_created ON payments (uid, created_at);
