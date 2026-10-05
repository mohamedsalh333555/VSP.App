-- Unify owner subscription pricing across web/app checkout and admin reporting.
-- Base plan price remains in amount; all payer-facing charges are stored separately.
alter table public.platform_fee_config
  add column if not exists subscription_vsp_rate numeric(8,6) not null default 0.020000,
  add column if not exists subscription_paymob_rate numeric(8,6) not null default 0.027500,
  add column if not exists subscription_paymob_fixed_fee numeric(12,2) not null default 3.00;

update public.platform_fee_config
set subscription_vsp_rate = booking_vsp_rate,
    subscription_paymob_rate = coalesce(booking_paymob_local_rate, booking_paymob_rate),
    subscription_paymob_fixed_fee = booking_paymob_fixed_fee
where id = 1;

alter table public.owner_subscription_orders
  add column if not exists vsp_fee_amount numeric(12,2),
  add column if not exists paymob_fee_amount numeric(12,2),
  add column if not exists gross_amount numeric(12,2);
