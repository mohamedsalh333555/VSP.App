-- Align the live payment-fee SSOT with the approved Paymob contract.
UPDATE public.platform_fee_config
SET
  booking_vsp_rate = 0.020000,
  booking_paymob_rate = 0.027500,
  booking_paymob_local_rate = 0.027500,
  booking_paymob_wallet_rate = 0.027500,
  booking_paymob_foreign_rate = 0.027500,
  booking_paymob_fixed_fee = 3.00,
  updated_at = timezone('utc', now())
WHERE id = 1;
