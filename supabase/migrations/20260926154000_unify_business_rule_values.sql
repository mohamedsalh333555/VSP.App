-- Unified business rule values -- 2026-09-26
update public.platform_business_rules
set booking_past_grace_minutes=8,
    late_cancellation_cutoff_hours=6,
    updated_at=now()
where id=1;
