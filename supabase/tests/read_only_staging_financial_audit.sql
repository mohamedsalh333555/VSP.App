-- VSP read-only Staging-only financial/refund readiness audit.
-- Returns ONLY aggregate counts and metadata; no customer/booking/payment IDs,
-- secrets, amounts or individual records. Do not run on production by default.
-- This script DOES NOT process refunds or mutate data.
select
 (select count(*) from public.bookings) as bookings_total,
 (select count(*) from public.bookings where paymob_txn_id is not null
  and paymob_transaction_id is not null
  and paymob_txn_id<>paymob_transaction_id) as booking_alias_disagreements,
 (select count(*) from (select paymob_txn_id from public.bookings
  where nullif(trim(paymob_txn_id),'') is not null
  group by paymob_txn_id having count(*)>1) dup) as duplicate_booking_txn_ids,
 (select count(*) from (select paymob_transaction_id from public.transactions
  where nullif(trim(paymob_transaction_id),'') is not null
  group by paymob_transaction_id having count(*)>1) dup) as duplicate_ledger_paymob_ids,
 (select count(*) from public.bookings where is_paid is true
  and lower(coalesce(payment_status,'')) in ('unpaid','pending','failed')) as paid_boolean_conflicts,
 (select count(*) from public.bookings where is_paid is false
  and lower(coalesce(payment_status,'')) in ('paid','fully_paid')) as unpaid_boolean_conflicts,
 (select count(*) from public.users) as users_total,
 (select count(*) from public.users
  where coalesce(accumulated_cash_debt,0)>0) as users_positive_cash_debt,
 (select count(*) from public.users where cash_booking_banned is true) as banned_cash_count,
 (select count(*) from public.users where is_debt_blocked is true) as debt_blocked_count,
 (select count(*) from public.users where coalesce(debt_limit,0)<>0) as configured_debt_limit_count;

-- Readiness diagnostics: no secret values returned. A true cron activity flag
-- does NOT mean the worker can execute a refund successfully.
select j.jobname,j.schedule,j.active,
 (select count(*) from public.internal_function_secrets
  where name='refund_worker')>0 as refund_worker_secret_name_present
from cron.job j
where j.command ilike '%reconcile_cancellation_refund_queue%';
