-- Restore canonical reference rows that exist in Production but were absent
-- from the isolated Staging environment. Existing values are never overwritten.

INSERT INTO public.league_settings (setting_key, setting_value)
VALUES ('team_league_entry_fee', '30')
ON CONFLICT (setting_key) DO NOTHING;

INSERT INTO public.subscription_plans (
  code, name_ar, name_en, description_ar, description_en,
  monthly_price, yearly_price, trial_days, max_stadiums,
  features, is_active, display_order
)
VALUES
  (
    'basic', 'مجاني', 'Free',
    'مجاني لإدارة ملعب واحد مع أدوات التشغيل والحجوزات الأساسية.',
    'Free for managing one stadium with core operations and booking tools.',
    0, 0, 0, 1,
    '{"support":"standard","ai_insights":false,"cash_booking":true,"excel_reports":false,"atomic_booking":true,"online_booking":true,"shift_management":true,"no_show_protection":true,"search_priority_boost":false,"tournament_management":true,"whatsapp_confirmation":false}'::jsonb,
    true, 10
  ),
  (
    'pro', 'الباقة الاحترافية', 'Pro Plan',
    'اشتراك احترافي شهري يفتح المزايا المتقدمة وإدارة حتى 3 ملاعب مع تجربة 7 أيام مجاناً.',
    'Professional monthly subscription unlocking advanced features and up to 3 stadiums with a 7-day free trial.',
    1000, 11000, 7, 3,
    '{"support":"priority_24_7","ai_insights":true,"cash_booking":true,"excel_reports":true,"atomic_booking":true,"online_booking":true,"shift_management":true,"no_show_protection":true,"search_priority_boost":true,"tournament_management":true,"whatsapp_confirmation":true}'::jsonb,
    true, 20
  )
ON CONFLICT (code) DO NOTHING;

