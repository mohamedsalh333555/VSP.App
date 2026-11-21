# VSP — Repeat booking, safe entrypoint (18 November 2026)

Status: **CODE SUBMITTED / NOT STAGING-ACCEPTED**. Existing task 86.06 stays OPEN.

- Personal booking history offers localized "Book again / احجز تاني" only after the original booked time, without treating team matches, challenges or cancelled/no-show/payment-expired bookings as equivalent.
- The action never creates, retries or pays for a booking. It calls the existing strict server lookup for the *current* published, unblocked stadium and opens the existing StadiumDetailsScreen only on success; server details stream and booking price/slot preflight remain authoritative. It never injects the prior date, rent, price, deposit or payment method into a new draft.
- Double tap is disabled while the lookup is pending; missing/mismatched/blocked stadium, thrown RPC and lost account scope do not navigate. Error strings are localized/sanitized.
- Scoped widget tests: fresh fetched value, pending double-tap, missing venue, account switch, private error masking and wrong stadium ID. These use a controlled future and are **not** proof of Supabase Staging, Paymob sandbox, a real two-account journey, or Android device acceptance.
- No changes to Home content, payments, schema, revenue, production, Admin Panel or Website. The Phase 10 86.06 task requires real fresh-price/deposit/slot/explicit-confirmation/integrated journey tests before acceptance.
