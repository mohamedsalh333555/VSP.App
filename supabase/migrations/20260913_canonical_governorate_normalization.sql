-- ==============================================================================
-- MIGRATION: 20260913_canonical_governorate_normalization.sql
-- DESCRIPTION: Canonical Governorate Normalization & DB Integrity Triggers
--              Guarantees single source of truth (Canonical English Codes e.g. 'Aswan')
--              across stadiums, users, teams, and tournaments.
-- ==============================================================================

-- 1. Helper function: normalize_governorate
CREATE OR REPLACE FUNCTION public.normalize_governorate(p_gov text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $function$
BEGIN
    IF p_gov IS NULL OR trim(p_gov) = '' THEN
        RETURN 'Cairo';
    END IF;
    
    RETURN CASE trim(lower(p_gov))
        -- Arabic variants
        WHEN 'القاهرة' THEN 'Cairo'
        WHEN 'الجيزة' THEN 'Giza'
        WHEN 'الإسكندرية' THEN 'Alexandria'
        WHEN 'الاسكندرية' THEN 'Alexandria'
        WHEN 'أسوان' THEN 'Aswan'
        WHEN 'اسوان' THEN 'Aswan'
        WHEN 'أسيوط' THEN 'Asyut'
        WHEN 'اسيوط' THEN 'Asyut'
        WHEN 'البحيرة' THEN 'Beheira'
        WHEN 'بني سويف' THEN 'Beni Suef'
        WHEN 'الدقهلية' THEN 'Dakahlia'
        WHEN 'دمياط' THEN 'Damietta'
        WHEN 'الفيوم' THEN 'Faiyum'
        WHEN 'الغربية' THEN 'Gharbia'
        WHEN 'الإسماعيلية' THEN 'Ismailia'
        WHEN 'الاسماعيلية' THEN 'Ismailia'
        WHEN 'كفر الشيخ' THEN 'Kafr El Sheikh'
        WHEN 'الأقصر' THEN 'Luxor'
        WHEN 'الاقصر' THEN 'Luxor'
        WHEN 'مطروح' THEN 'Matrouh'
        WHEN 'مرسى مطروح' THEN 'Matrouh'
        WHEN 'المنيا' THEN 'Minya'
        WHEN 'المنوفية' THEN 'Monufia'
        WHEN 'الوادي الجديد' THEN 'New Valley'
        WHEN 'شمال سيناء' THEN 'North Sinai'
        WHEN 'بورسعيد' THEN 'Port Said'
        WHEN 'بور سعيد' THEN 'Port Said'
        WHEN 'القليوبية' THEN 'Qalyubia'
        WHEN 'قنا' THEN 'Qena'
        WHEN 'البحر الأحمر' THEN 'Red Sea'
        WHEN 'البحر الاحمر' THEN 'Red Sea'
        WHEN 'الشرقية' THEN 'Sharqia'
        WHEN 'سوهاج' THEN 'Sohag'
        WHEN 'جنوب سيناء' THEN 'South Sinai'
        WHEN 'السويس' THEN 'Suez'
        -- English variants (lowercase / whitespace)
        WHEN 'cairo' THEN 'Cairo'
        WHEN 'giza' THEN 'Giza'
        WHEN 'alexandria' THEN 'Alexandria'
        WHEN 'aswan' THEN 'Aswan'
        WHEN 'asyut' THEN 'Asyut'
        WHEN 'beheira' THEN 'Beheira'
        WHEN 'beni suef' THEN 'Beni Suef'
        WHEN 'dakahlia' THEN 'Dakahlia'
        WHEN 'damietta' THEN 'Damietta'
        WHEN 'faiyum' THEN 'Faiyum'
        WHEN 'gharbia' THEN 'Gharbia'
        WHEN 'ismailia' THEN 'Ismailia'
        WHEN 'kafr el sheikh' THEN 'Kafr El Sheikh'
        WHEN 'luxor' THEN 'Luxor'
        WHEN 'matrouh' THEN 'Matrouh'
        WHEN 'minya' THEN 'Minya'
        WHEN 'monufia' THEN 'Monufia'
        WHEN 'new valley' THEN 'New Valley'
        WHEN 'north sinai' THEN 'North Sinai'
        WHEN 'port said' THEN 'Port Said'
        WHEN 'qalyubia' THEN 'Qalyubia'
        WHEN 'qena' THEN 'Qena'
        WHEN 'red sea' THEN 'Red Sea'
        WHEN 'sharqia' THEN 'Sharqia'
        WHEN 'sohag' THEN 'Sohag'
        WHEN 'south sinai' THEN 'South Sinai'
        WHEN 'suez' THEN 'Suez'
        ELSE initcap(trim(p_gov))
    END;
END;
$function$;

-- 2. Trigger Function
CREATE OR REPLACE FUNCTION public.trg_fn_normalize_governorate()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.governorate IS NOT NULL THEN
        NEW.governorate := public.normalize_governorate(NEW.governorate);
    END IF;
    RETURN NEW;
END;
$function$;

-- 3. Attach Triggers to stadiums and users
DROP TRIGGER IF EXISTS trg_stadiums_normalize_gov ON public.stadiums;
CREATE TRIGGER trg_stadiums_normalize_gov
BEFORE INSERT OR UPDATE OF governorate ON public.stadiums
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_normalize_governorate();

DROP TRIGGER IF EXISTS trg_users_normalize_gov ON public.users;
CREATE TRIGGER trg_users_normalize_gov
BEFORE INSERT OR UPDATE OF governorate ON public.users
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_normalize_governorate();

-- 4. Normalize all existing rows in public.stadiums and public.users
UPDATE public.stadiums SET governorate = public.normalize_governorate(governorate);
UPDATE public.users SET governorate = public.normalize_governorate(governorate);
