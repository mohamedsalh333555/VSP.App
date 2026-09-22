-- ============================================================================
-- VSP Real Aswan Seed Dataset (100% Reversible via public.purge_aswan_seed_data)
-- ============================================================================

DO $$
DECLARE
    -- Owner IDs
    o1 uuid := 'a1000000-0000-0000-0000-000000000001'::uuid;
    o2 uuid := 'a1000000-0000-0000-0000-000000000002'::uuid;
    o3 uuid := 'a1000000-0000-0000-0000-000000000003'::uuid;
    o4 uuid := 'a1000000-0000-0000-0000-000000000004'::uuid;
    o5 uuid := 'a1000000-0000-0000-0000-000000000005'::uuid;
    o6 uuid := 'a1000000-0000-0000-0000-000000000006'::uuid;
    o7 uuid := 'a1000000-0000-0000-0000-000000000007'::uuid;
    o8 uuid := 'a1000000-0000-0000-0000-000000000008'::uuid;
    o9 uuid := 'a1000000-0000-0000-0000-000000000009'::uuid;
    o10 uuid := 'a1000000-0000-0000-0000-000000000010'::uuid;

    -- Stadium IDs
    s1 uuid := 'b1000000-0000-0000-0000-000000000001'::uuid;
    s2 uuid := 'b1000000-0000-0000-0000-000000000002'::uuid;
    s3 uuid := 'b1000000-0000-0000-0000-000000000003'::uuid;
    s4 uuid := 'b1000000-0000-0000-0000-000000000004'::uuid;
    s5 uuid := 'b1000000-0000-0000-0000-000000000005'::uuid;
    s6 uuid := 'b1000000-0000-0000-0000-000000000006'::uuid;
    s7 uuid := 'b1000000-0000-0000-0000-000000000007'::uuid;
    s8 uuid := 'b1000000-0000-0000-0000-000000000008'::uuid;
    s9 uuid := 'b1000000-0000-0000-0000-000000000009'::uuid;
    s10 uuid := 'b1000000-0000-0000-0000-000000000010'::uuid;

    -- Team IDs
    t1 uuid := 'c1000000-0000-0000-0000-000000000001'::uuid;
    t2 uuid := 'c1000000-0000-0000-0000-000000000002'::uuid;
    t3 uuid := 'c1000000-0000-0000-0000-000000000003'::uuid;
    t4 uuid := 'c1000000-0000-0000-0000-000000000004'::uuid;
    t5 uuid := 'c1000000-0000-0000-0000-000000000005'::uuid;
    t6 uuid := 'c1000000-0000-0000-0000-000000000006'::uuid;
    t7 uuid := 'c1000000-0000-0000-0000-000000000007'::uuid;
    t8 uuid := 'c1000000-0000-0000-0000-000000000008'::uuid;
    t9 uuid := 'c1000000-0000-0000-0000-000000000009'::uuid;
    t10 uuid := 'c1000000-0000-0000-0000-000000000010'::uuid;

    -- Championship ID
    champ_id uuid := 'd1000000-0000-0000-0000-000000000001'::uuid;

    -- 1v1 Tournament ID
    tourney_1v1_id uuid := 'e1000000-0000-0000-0000-000000000001'::uuid;

    -- Public Match Booking ID
    pub_match_id uuid := 'f1000000-0000-0000-0000-000000000001'::uuid;

    -- Helper variables
    i int;
    curr_player_id uuid;
    curr_team_id uuid;
    p_names text[] := ARRAY[
        -- Team 1: نمور النوبة (1..5)
        'يوسف الأسواني', 'أحمد كبوشي', 'محمود شلبي', 'عمر دهب', 'حمادة الساحر',
        -- Team 2: فرسان فيلة (6..10)
        'عبد الرحمن طه', 'مصطفى النميري', 'طارق غريب', 'وليد عبد العال', 'محمد قوصي',
        -- Team 3: تماسيح النيل (11..15)
        'عمر النوبي', 'زياد الصاوي', 'مروان كمال', 'إسلام النجار', 'حسام كروان',
        -- Team 4: صقور دراو (16..20)
        'خالد الجبلاوي', 'رامي الكومي', 'معتز سليم', 'عصام حربي', 'نادر فوزي',
        -- Team 5: أبطال إدفو (21..25)
        'حازم رضوان', 'عادل البصيلية', 'سامح الصعايدة', 'كريم فراج', 'سامي الباسل',
        -- Team 6: نجوم السد العالي (26..30)
        'مصطفى بدر', 'شادي ممدوح', 'باسم الحلفاوي', 'وائل عنتر', 'إيهاب الصيرفي',
        -- Team 7: فهود كوم أمبو (31..35)
        'كريم شحاتة', 'أشرف البصيلية', 'هيثم دهموش', 'أحمد الروبي', 'ماجد مروان',
        -- Team 8: ملوك الأندلس (36..40)
        'حمزة قاسم', 'هشام الفولي', 'تامر خليل', 'ياسين الأزهري', 'مدحت صابر',
        -- Team 9: شمس أسوان (41..45)
        'بلال زكي', 'شريف عبد الصمد', 'عماد البربري', 'فريد شوقي', 'أسامة كمال',
        -- Team 10: ذئاب الجبل (46..50)
        'طارق منصور', 'هاني الصفتي', 'عاطف الرشيدي', 'فادي نخلة', 'مايكل جرجس'
    ];
    p_positions text[] := ARRAY['مهاجم', 'حارس مرمى', 'مدافع', 'خط وسط', 'جناح'];
BEGIN

    -- ------------------------------------------------------------------------
    -- 1. INSERT 10 OWNERS INTO auth.users & UPDATE public.users
    -- ------------------------------------------------------------------------
    INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous, created_at, updated_at)
    VALUES
      (o1, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'mahmoud.abnoudy@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "محمود الأبنودي", "role": "owner", "phone": "01123450001", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o2, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'abdullah.nouby@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "عبد الله النوبي", "role": "owner", "phone": "01123450002", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o3, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'mostafa.idrees@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "مصطفى إدريس", "role": "owner", "phone": "01123450003", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o4, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'hassan.bahr@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "حسن بحر", "role": "owner", "phone": "01123450004", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o5, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'ahmed.toshka@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "أحمد توشكا", "role": "owner", "phone": "01123450005", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o6, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'tarek.philae@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "طارق فيلة", "role": "owner", "phone": "01123450006", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o7, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'ali.komatero@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "علي كوماتيرو", "role": "owner", "phone": "01123450007", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o8, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'selim.aswany@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "سليم الأسواني", "role": "owner", "phone": "01123450008", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o9, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'yassin.dandarawy@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "ياسين الدندراوي", "role": "owner", "phone": "01123450009", "governorate": "Aswan"}'::jsonb, false, false, now(), now()),
      (o10, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', 'karim.gaafary@aswan.seed.vsp.app', '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567', now(), '{"provider": "email", "providers": ["email"]}'::jsonb, '{"name": "كريم الجعفري", "role": "owner", "phone": "01123450010", "governorate": "Aswan"}'::jsonb, false, false, now(), now())
    ON CONFLICT (id) DO NOTHING;

    -- Enhance owner properties in public.users
    UPDATE public.users
    SET is_registration_complete = true,
        is_onboarding_confirmed = true,
        is_identity_verified = true,
        has_stadium = true,
        additional_data = '{"seed_tag": "aswan_seed_2026"}'::jsonb,
        verification_status = 'verified'
    WHERE id >= o1 AND id <= o10;

    -- ------------------------------------------------------------------------
    -- 2. INSERT 10 STADIUMS IN ASWAN
    -- ------------------------------------------------------------------------
    INSERT INTO public.stadiums (id, owner_id, name, location, governorate, city, price_per_hour, base_price, seats_capacity, rating, reviews_count, is_verified, is_featured, is_blocked, players_per_team, total_field_capacity, lat, lng, image_url, images, description, features)
    VALUES
      (s1, o1, 'ستاد أسوان الدولي', 'أسوان - كورنيش النيل بجوار الحديقة الدولية', 'Aswan', 'أسوان', 450, 450, 500, 4.9, 42, true, true, false, 5, 10, 24.0889, 32.8998, 'https://images.unsplash.com/photo-1529900241065-492723cfa018?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1529900241065-492723cfa018?auto=format&fit=crop&w=800&q=80'], 'ستاد مجهز بأحدث معايير النجيل الصناعي المعتمد وإضاءة ليلية عالية الكفاءة وكافيتريا وغرف تبديل ملابس.', '{"parking": true, "lighting": true, "cafeteria": true, "showers": true}'::jsonb),
      (s2, o2, 'ملعب النوبة الرياضي', 'غرب أسوان - قرية غرب سهيل النوبية', 'Aswan', 'أسوان', 300, 300, 200, 4.8, 35, true, true, false, 5, 10, 24.0621, 32.8752, 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=800&q=80'], 'ملعب رائع بإطلالة نوبية ساحرة، نجيل ممتاز وأجواء حماسية وتجهيزات متكاملة.', '{"parking": true, "lighting": true, "cafeteria": true}'::jsonb),
      (s3, o3, 'مجمع فيلة الرياضي', 'الشلال - طريق السد القديم بجوار معبد فيلة', 'Aswan', 'أسوان', 350, 350, 300, 4.7, 28, true, false, false, 5, 10, 24.0256, 32.8841, 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=800&q=80'], 'مجمع رياضي متكامل بمقاعد جماهيرية ومضمار للجري وخدمات فندقية.', '{"parking": true, "lighting": true, "showers": true}'::jsonb),
      (s4, o4, 'ملعب دراو الرئيسي', 'مركز دراو - الشارع العمومي بجوار المحطة', 'Aswan', 'دراو', 250, 250, 150, 4.6, 19, true, false, false, 5, 10, 24.3644, 32.9312, 'https://images.unsplash.com/photo-1459865264687-595d652de67e?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1459865264687-595d652de67e?auto=format&fit=crop&w=800&q=80'], 'ملعب خماسي هادئ بنجيل تركي مستورد وإضاءة ممتازة لحجز المجموعات والتحديات.', '{"parking": true, "lighting": true}'::jsonb),
      (s5, o5, 'ستاد إدفو الرياضي', 'مركز إدفو - الكورنيش بجوار معبد حورس', 'Aswan', 'إدفو', 280, 280, 250, 4.8, 31, true, false, false, 5, 10, 24.9782, 32.8754, 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=800&q=80'], 'أشهر ملاعب إدفو للمباريات الرسمية والبطولات الخماسية.', '{"parking": true, "lighting": true, "cafeteria": true}'::jsonb),
      (s6, o6, 'ملعب السد العالي', 'منطقة السد العالي - محطة المحولات', 'Aswan', 'أسوان', 320, 320, 200, 4.7, 24, true, false, false, 5, 10, 23.9701, 32.8773, 'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1518091043644-c1d4457512c6?auto=format&fit=crop&w=800&q=80'], 'ملعب مفتوح على النيل بجوار السد العالي ومجهز بالكامل للمباريات الليلية.', '{"parking": true, "lighting": true}'::jsonb),
      (s7, o7, 'ملعب كورنيش النيل', 'طريق الكورنيش الجديد - أمام نادي التجديف', 'Aswan', 'أسوان', 400, 400, 350, 4.9, 48, true, true, false, 5, 10, 24.0954, 32.9021, 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1556056504-5c7696c4c28d?auto=format&fit=crop&w=800&q=80'], 'موقع استثنائي على النيل مباشرة، نجيل فائق الجودة وخدمات VIP للاعبين والفرق.', '{"parking": true, "lighting": true, "cafeteria": true, "wifi": true}'::jsonb),
      (s8, o8, 'ملعب جزيرة النباتات', 'جزيرة النباتات - أسوان', 'Aswan', 'أسوان', 380, 380, 150, 4.8, 22, true, false, false, 5, 10, 24.0911, 32.8894, 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80'], 'تجربة كروية فريدة وسط الطبيعة والنيل والهدوء التام.', '{"lighting": true, "cafeteria": true}'::jsonb),
      (s9, o9, 'مجمع كوم أمبو الرياضي', 'كوم أمبو - شارع بورسعيد بجوار المستشفى المركزي', 'Aswan', 'كوم أمبو', 260, 260, 200, 4.6, 27, true, false, false, 5, 10, 24.4764, 32.9467, 'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&w=800&q=80'], 'ملعب شباب كوم أمبو الأول للتحديات والمباريات السريعة.', '{"parking": true, "lighting": true}'::jsonb),
      (s10, o10, 'ملعب الأندلس كوماتيرو', 'حي العقاد - أسوان بجوار قصر الثقافة', 'Aswan', 'أسوان', 300, 300, 180, 4.7, 33, true, false, false, 5, 10, 24.0782, 32.9125, 'https://images.unsplash.com/photo-1511886929837-354d827aae26?auto=format&fit=crop&w=800&q=80', ARRAY['https://images.unsplash.com/photo-1511886929837-354d827aae26?auto=format&fit=crop&w=800&q=80'], 'ملعب متميز في قلب حي العقاد، أرضية نجيلية مريحة وإضاءة ممتازة.', '{"parking": true, "lighting": true, "cafeteria": true}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 3. INSERT 50 PLAYERS INTO auth.users & UPDATE public.users
    -- ------------------------------------------------------------------------
    FOR i IN 1..50 LOOP
        curr_player_id := ('00000000-0000-0000-0000-' || LPAD(i::text, 12, '0'))::uuid;
        
        INSERT INTO auth.users (
            id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous, created_at, updated_at
        )
        VALUES (
            curr_player_id,
            '00000000-0000-0000-0000-000000000000'::uuid,
            'authenticated',
            'authenticated',
            'player_' || LPAD(i::text, 2, '0') || '@aswan.seed.vsp.app',
            '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789012345678901234567',
            now(),
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            jsonb_build_object(
                'name', p_names[i],
                'role', 'player',
                'phone', '0102345' || LPAD(i::text, 4, '0'),
                'governorate', 'Aswan',
                'position', p_positions[((i - 1) % 5) + 1]
            ),
            false, false, now(), now()
        )
        ON CONFLICT (id) DO NOTHING;

        UPDATE public.users
        SET is_registration_complete = true,
            is_onboarding_confirmed = true,
            is_identity_verified = true,
            points = (100 - i) * 10,
            additional_data = '{"seed_tag": "aswan_seed_2026"}'::jsonb,
            verification_status = 'verified'
        WHERE id = curr_player_id;
    END LOOP;

    -- ------------------------------------------------------------------------
    -- 4. INSERT 10 TEAMS (WITH 1v1 CHAMPION IN EXACTLY TWO TEAMS: t1 & t3)
    -- ------------------------------------------------------------------------
    INSERT INTO public.teams (id, name, captain_id, governorate, sport_type, points, wins, draws, losses, matches_played, current_winning_streak, championships_won, has_1v1_champion, is_official, attendance_score, verified_badge, primary_color, secondary_color)
    VALUES
      (t1, 'نمور النوبة', '00000000-0000-0000-0000-000000000001'::uuid, 'Aswan', 'football', 20, 6, 2, 1, 9, 3, 1, true, true, 9.8, true, '#FFD700', '#000000'),
      (t2, 'فرسان فيلة', '00000000-0000-0000-0000-000000000006'::uuid, 'Aswan', 'football', 15, 4, 3, 2, 9, 1, 0, false, true, 9.2, true, '#1E3A8A', '#FFFFFF'),
      (t3, 'تماسيح النيل', '00000000-0000-0000-0000-000000000011'::uuid, 'Aswan', 'football', 22, 7, 1, 1, 9, 4, 2, true, true, 9.9, true, '#047857', '#F59E0B'),
      (t4, 'صقور دراو', '00000000-0000-0000-0000-000000000016'::uuid, 'Aswan', 'football', 16, 5, 1, 3, 9, 2, 0, false, true, 9.0, false, '#B91C1C', '#FFFFFF'),
      (t5, 'أبطال إدفو', '00000000-0000-0000-0000-000000000021'::uuid, 'Aswan', 'football', 14, 4, 2, 3, 9, 1, 0, false, true, 8.9, false, '#7C3AED', '#FFFFFF'),
      (t6, 'نجوم السد العالي', '00000000-0000-0000-0000-000000000026'::uuid, 'Aswan', 'football', 13, 4, 1, 4, 9, 0, 0, false, true, 8.8, false, '#0284C7', '#FFFFFF'),
      (t7, 'فهود كوم أمبو', '00000000-0000-0000-0000-000000000031'::uuid, 'Aswan', 'football', 11, 3, 2, 4, 9, 1, 0, false, true, 8.5, false, '#D97706', '#000000'),
      (t8, 'ملوك الأندلس', '00000000-0000-0000-0000-000000000036'::uuid, 'Aswan', 'football', 10, 3, 1, 5, 9, 0, 0, false, true, 8.4, false, '#4B5563', '#FFFFFF'),
      (t9, 'شمس أسوان', '00000000-0000-0000-0000-000000000041'::uuid, 'Aswan', 'football', 8, 2, 2, 5, 9, 0, 0, false, true, 8.0, false, '#F59E0B', '#1E3A8A'),
      (t10, 'ذئاب الجبل', '00000000-0000-0000-0000-000000000046'::uuid, 'Aswan', 'football', 6, 2, 0, 7, 9, 0, 0, false, true, 7.9, false, '#111827', '#EF4444')
    ON CONFLICT (id) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 5. INSERT TEAM MEMBERS (5 PLAYERS PER TEAM)
    -- ------------------------------------------------------------------------
    FOR i IN 1..50 LOOP
        curr_player_id := ('00000000-0000-0000-0000-' || LPAD(i::text, 12, '0'))::uuid;
        curr_team_id := ('c1000000-0000-0000-0000-' || LPAD((((i - 1) / 5) + 1)::text, 12, '0'))::uuid;
        
        INSERT INTO public.team_members (team_id, user_id, joined_at)
        VALUES (curr_team_id, curr_player_id, now() - interval '30 days')
        ON CONFLICT (team_id, user_id) DO NOTHING;
    END LOOP;

    -- ------------------------------------------------------------------------
    -- 6. TROPHIES FOR THE TWO 1v1 CHAMPIONS
    -- ------------------------------------------------------------------------
    INSERT INTO public.player_trophies (id, user_id, title, prize_won, created_at)
    VALUES
      ('e2000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 'بطل دورة أسوان الفردية 1v1', 3000, now() - interval '15 days'),
      ('e2000000-0000-0000-0000-000000000002'::uuid, '00000000-0000-0000-0000-000000000011'::uuid, 'كأس التحدي الفردي أسوان 1v1', 2500, now() - interval '8 days')
    ON CONFLICT (id) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 7. 1v1 TOURNAMENT & RANKINGS FOR ALL 50 PLAYERS
    -- ------------------------------------------------------------------------
    INSERT INTO public.vsp_1v1_tournaments (
        id, name, target_player_count, status, created_by, published_at, scheduled_at,
        champion_user_id, entry_fee, prize_pool, prize_delivered, prize_delivered_at, governorate, created_at, updated_at
    )
    VALUES (
        tourney_1v1_id,
        'بطولة أسوان الأولى لمهارات 1 ضد 1',
        50,
        'completed',
        o1,
        now() - interval '10 days',
        now() - interval '9 days',
        '00000000-0000-0000-0000-000000000001'::uuid,
        100,
        5000,
        true,
        now() - interval '9 days',
        'Aswan',
        now() - interval '15 days',
        now() - interval '9 days'
    )
    ON CONFLICT (id) DO NOTHING;

    -- Populate 1v1 Tournament Players and Global 1v1 Players
    FOR i IN 1..50 LOOP
        curr_player_id := ('00000000-0000-0000-0000-' || LPAD(i::text, 12, '0'))::uuid;
        
        -- Global 1v1 player profile
        INSERT INTO public.vsp_1vs1_players (
            id, name, total_points, skill_points, goals, tackles, titles, trend, created_at, updated_at
        )
        VALUES (
            curr_player_id,
            p_names[i],
            1300 - (i * 20),
            400 - (i * 5),
            35 - (i / 2),
            45 - (i / 2),
            CASE WHEN i = 1 THEN 2 WHEN i = 11 THEN 1 ELSE 0 END,
            CASE WHEN i = 1 THEN 'up' WHEN i <= 5 THEN 'stable' ELSE 'down' END,
            now() - interval '20 days',
            now()
        )
        ON CONFLICT (id) DO UPDATE SET
            total_points = EXCLUDED.total_points,
            skill_points = EXCLUDED.skill_points,
            goals = EXCLUDED.goals,
            tackles = EXCLUDED.tackles,
            titles = EXCLUDED.titles;

        -- Tournament player registration
        INSERT INTO public.vsp_1v1_tournament_players (
            id, tournament_id, user_id, player_name, tackles, goals, skills, payment_status, paid_amount, created_at, updated_at, registered_at
        )
        VALUES (
            gen_random_uuid(),
            tourney_1v1_id,
            curr_player_id,
            p_names[i],
            40 - (i / 2),
            30 - (i / 2),
            350 - (i * 5),
            'paid',
            100,
            now() - interval '12 days',
            now() - interval '9 days',
            now() - interval '12 days'
        );
    END LOOP;

    -- ------------------------------------------------------------------------
    -- 8. ACTIVE CHAMPIONSHIP WITH 10 TEAMS (IN PROGRESS)
    -- ------------------------------------------------------------------------
    INSERT INTO public.championships (
        id, name, type, sport_type, start_date, end_date, entry_fee, grand_prize, max_teams,
        owner_id, governorate, status, is_approved, joined_teams, paid_teams, prize_pool, prize_delivered,
        number_of_groups, qualifying_per_group, created_at, updated_at
    )
    VALUES (
        champ_id,
        'دوري أبطال أسوان للملاعب الخماسية 2026',
        'groups',
        'football',
        now() - interval '7 days',
        now() + interval '14 days',
        1000,
        25000,
        10,
        o1,
        'Aswan',
        'ongoing',
        true,
        ARRAY[t1, t2, t3, t4, t5, t6, t7, t8, t9, t10],
        ARRAY[t1, t2, t3, t4, t5, t6, t7, t8, t9, t10],
        25000,
        false,
        2,
        2,
        now() - interval '14 days',
        now()
    )
    ON CONFLICT (id) DO NOTHING;

    -- Tournament Matches in Championship
    INSERT INTO public.tournament_matches (
        id, championship_id, round_index, match_index, home_team_id, home_team_name, away_team_id, away_team_name,
        home_score, away_score, winner_id, winner_name, status, is_completed, scheduled_time, stage, group_name
    )
    VALUES
      -- Completed matches
      (gen_random_uuid(), champ_id, 1, 1, t1, 'نمور النوبة', t2, 'فرسان فيلة', 3, 2, t1, 'نمور النوبة', 'completed', true, now() - interval '5 days', 'group_stage', 'المجموعة الأولى'),
      (gen_random_uuid(), champ_id, 1, 2, t3, 'تماسيح النيل', t4, 'صقور دراو', 4, 1, t3, 'تماسيح النيل', 'completed', true, now() - interval '4 days', 'group_stage', 'المجموعة الأولى'),
      (gen_random_uuid(), champ_id, 1, 3, t5, 'أبطال إدفو', t6, 'نجوم السد العالي', 2, 2, null, null, 'completed', true, now() - interval '3 days', 'group_stage', 'المجموعة الثانية'),
      (gen_random_uuid(), champ_id, 1, 4, t7, 'فهود كوم أمبو', t8, 'ملوك الأندلس', 1, 0, t7, 'فهود كوم أمبو', 'completed', true, now() - interval '2 days', 'group_stage', 'المجموعة الثانية'),
      -- Upcoming matches
      (gen_random_uuid(), champ_id, 2, 1, t1, 'نمور النوبة', t3, 'تماسيح النيل', null, null, null, null, 'scheduled', false, now() + interval '1 day' + interval '19 hours', 'group_stage', 'المجموعة الأولى'),
      (gen_random_uuid(), champ_id, 2, 2, t2, 'فرسان فيلة', t4, 'صقور دراو', null, null, null, null, 'scheduled', false, now() + interval '2 days' + interval '20 hours', 'group_stage', 'المجموعة الأولى'),
      (gen_random_uuid(), champ_id, 2, 3, t5, 'أبطال إدفو', t7, 'فهود كوم أمبو', null, null, null, null, 'scheduled', false, now() + interval '3 days' + interval '19 hours', 'group_stage', 'المجموعة الثانية')
    ON CONFLICT (id) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 9. PAST CHALLENGE MATCHES & HEAD TO HEAD
    -- ------------------------------------------------------------------------
    -- Past Challenge 1: t3 (تماسيح النيل) vs t1 (نمور النوبة) at Stadium 1
    INSERT INTO public.bookings (
        id, stadium_id, stadium_name, owner_id, created_by_user_id,
        start_time, end_time, booking_type, player_team_id, player_team_name,
        opponent_team_id, opponent_team_name, is_private, total_price,
        status, is_paid, payment_status, home_score, away_score,
        match_result_status, final_outcome, challenge_status, created_at, updated_at
    )
    VALUES (
        gen_random_uuid(), s1, 'ستاد أسوان الدولي', o1, '00000000-0000-0000-0000-000000000011'::uuid,
        now() - interval '6 days', now() - interval '6 days' + interval '1.5 hours',
        'challenge', t3, 'تماسيح النيل', t1, 'نمور النوبة', false, 450,
        'completed', true, 'paid', 3, 2, 'confirmed', 'homeWin', 'completed',
        now() - interval '7 days', now() - interval '6 days'
    );

    -- Past Challenge 2: t4 (صقور دراو) vs t2 (فرسان فيلة) at Stadium 4
    INSERT INTO public.bookings (
        id, stadium_id, stadium_name, owner_id, created_by_user_id,
        start_time, end_time, booking_type, player_team_id, player_team_name,
        opponent_team_id, opponent_team_name, is_private, total_price,
        status, is_paid, payment_status, home_score, away_score,
        match_result_status, final_outcome, challenge_status, created_at, updated_at
    )
    VALUES (
        gen_random_uuid(), s4, 'ملعب دراو الرئيسي', o4, '00000000-0000-0000-0000-000000000016'::uuid,
        now() - interval '4 days', now() - interval '4 days' + interval '1.5 hours',
        'challenge', t4, 'صقور دراو', t2, 'فرسان فيلة', false, 250,
        'completed', true, 'paid', 2, 2, 'confirmed', 'draw', 'completed',
        now() - interval '5 days', now() - interval '4 days'
    );

    -- Head to head entries
    INSERT INTO public.team_head_to_head (team_a_id, team_b_id, team_a_wins, team_b_wins, draws, updated_at)
    VALUES
      (t1, t3, 0, 1, 0, now() - interval '6 days'),
      (t2, t4, 0, 0, 1, now() - interval '4 days')
    ON CONFLICT (team_a_id, team_b_id) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 10. OPEN PUBLIC MATCH (WAITING FOR 4 PLAYERS AT ASWAN INTERNATIONAL STADIUM)
    -- ------------------------------------------------------------------------
    INSERT INTO public.bookings (
        id, stadium_id, stadium_name, owner_id, created_by_user_id,
        start_time, end_time, booking_type, is_private, total_price,
        status, is_paid, payment_status, current_players, max_players,
        total_field_capacity, initial_players_count, joined_user_ids,
        notes, created_at, updated_at
    )
    VALUES (
        pub_match_id,
        s1,
        'ستاد أسوان الدولي',
        o1,
        '00000000-0000-0000-0000-000000000001'::uuid,
        now() + interval '1 day' + interval '18 hours',
        now() + interval '1 day' + interval '19.5 hours',
        'open_join',
        false,
        450,
        'confirmed',
        true,
        'paid',
        6,
        5,
        10,
        6,
        ARRAY[
            '00000000-0000-0000-0000-000000000001'::uuid,
            '00000000-0000-0000-0000-000000000002'::uuid,
            '00000000-0000-0000-0000-000000000003'::uuid,
            '00000000-0000-0000-0000-000000000004'::uuid,
            '00000000-0000-0000-0000-000000000005'::uuid,
            '00000000-0000-0000-0000-000000000006'::uuid
        ],
        'مباراة مفتوحة 5 ضد 5 - ننتظر 4 لاعبين لإكمال التشكيل في ستاد أسوان الدولي',
        now(),
        now()
    )
    ON CONFLICT (id) DO NOTHING;

    -- Booking Players records for the 6 joined users
    FOR i IN 1..6 LOOP
        curr_player_id := ('00000000-0000-0000-0000-' || LPAD(i::text, 12, '0'))::uuid;
        INSERT INTO public.booking_players (booking_id, user_id, joined_at)
        VALUES (pub_match_id, curr_player_id, now())
        ON CONFLICT (booking_id, user_id) DO NOTHING;
    END LOOP;

    RAISE NOTICE 'Aswan Realistic Seed Dataset successfully injected!';
END $$;
