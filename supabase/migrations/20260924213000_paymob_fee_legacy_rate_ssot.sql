-- Keep the legacy aggregate Paymob rate aligned with the current checkout policy.
-- Policy: VSP 2% + Paymob 2.75% + EGP 3 per electronic booking payment.
update public.platform_fee_config
set booking_paymob_rate = 0.0275,
    updated_at = timezone('utc', now())
where id = 1;
