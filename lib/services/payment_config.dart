/// M-Pesa clock-out payment settings (DAITOM MOTORLINK LTD).
///
/// Paste the address printed by `npx wrangler deploy` for the daitom-pay worker,
/// e.g. `https://daitom-pay.<your-subdomain>.workers.dev`
/// (see payments_worker/README.md and SETUP_DAITOM.md).
///
/// - While this is empty, clock-out works as it always did: no prompt, nothing blocked.
/// - Once it is set, a rider with money to remit cannot finish clocking out unless
///   the M-Pesa PIN prompt is paid.
///
/// To switch the prompt off in an emergency, set it back to '' and rebuild.
const String kPaymentApiBase = 'https://daitom-pay.ultracem.workers.dev';

/// Derived - there is no second switch to forget.
const bool kMpesaPaymentEnabled = kPaymentApiBase != '';
