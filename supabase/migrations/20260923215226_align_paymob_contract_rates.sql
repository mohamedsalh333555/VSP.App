-- Paymob merchant-fee contract:
-- Local cards: 2.4% + 3 EGP
-- Foreign cards: 2.6% + 3 EGP
-- Wallets: 2.4% + 3 EGP
-- InstaPay: no configured online gateway fee
-- VSP platform commission remains 2.0% as a separate platform rule.
UPDATE public.platform_fee_config
SET
  booking_vsp_rate = 0.020000,
  booking_paymob_rate = 0.024000,
  booking_paymob_local_rate = 0.024000,
  booking_paymob_wallet_rate = 0.024000,
  booking_paymob_foreign_rate = 0.026000,
  booking_paymob_fixed_fee = 3.00,
  updated_at = timezone('utc', now())
WHERE id = 1;
