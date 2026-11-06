-- STAGING ONLY. Synthetic, non-login demo accounts and isolated Aswan fixtures.
-- Never apply to production. Email addresses use the reserved .invalid TLD.
-- Password hashes are random and discarded; accounts cannot be signed into.
DO $seed$
DECLARE
 i integer; j integer; uid uuid; tid uuid; oid uuid; sid uuid; tournament_id uuid;
 home_id uuid; away_id uuid; booking_id uuid; home_goals integer; away_goals integer;
 home_name text; away_name text;
 cities text[] := ARRAY['Aswan','Kom Ombo','Edfu','Daraw','Nasr Al Nuba'];
 BEGIN
 IF current_database() IS NULL THEN RAISE EXCEPTION 'Database unavailable'; END IF;
 -- Fail closed unless explicitly running against the known staging project.
 IF current_setting('app.settings.supabase_url',true) IS NOT NULL
    AND current_setting('app.settings.supabase_url',true) NOT LIKE '%vtwgqyxglevcsxwdmhop%' THEN
   RAISE EXCEPTION 'Refusing to seed outside staging';
 END IF;
 FOR i IN 1..110 LOOP
  uid := md5('vsp-aswan-demo-user-'||i)::uuid;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id=uid) THEN
   INSERT INTO auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
     raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
   VALUES(uid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
     'aswan-demo-'||i||'@vsp.invalid',
     crypt(gen_random_uuid()::text,gen_salt('bf')),
     now(), '{"provider":"email","providers":["email"]}'::jsonb,
     jsonb_build_object('demo',true,'governorate','Aswan'),now(),now());
   INSERT INTO auth.identities(provider_id,user_id,identity_data,provider)
   VALUES(uid::text,uid,jsonb_build_object('sub',uid::text,'email','aswan-demo-'||i||'@vsp.invalid'),'email');
  END IF;
  INSERT INTO public.users(id,email,name,role,governorate,is_registration_complete,has_stadium,additional_data)
  VALUES(uid,'aswan-demo-'||i||'@vsp.invalid',
    CASE WHEN i<=100 THEN '[DEMO] لاعب أسوان '||lpad(i::text,3,'0')
         ELSE '[DEMO] مالك ملعب أسوان '||(i-100) END,
    CASE WHEN i<=100 THEN 'player' ELSE 'owner' END,
    'Aswan',true,i>100,jsonb_build_object('is_demo',true,'seed','aswan-staging-v1'))
  ON CONFLICT (id) DO NOTHING;
 END LOOP;
 FOR i IN 1..15 LOOP
  sid := md5('vsp-aswan-demo-stadium-'||i)::uuid;
  oid := md5('vsp-aswan-demo-user-'||(101+(i-1)%10))::uuid;
  INSERT INTO public.stadiums(id,owner_id,name,location,governorate,city,price_per_hour,base_price,
     is_verified,is_featured,notes,description,players_per_team,total_field_capacity)
  VALUES(sid,oid,'[DEMO] ملعب أسوان '||lpad(i::text,2,'0'),
    cities[1+(i-1)%5]||' - Demo venue','Aswan',cities[1+(i-1)%5],
    250+25*(i%5),250+25*(i%5),false,false,
    'STAGING ONLY - SYNTHETIC - NOT A REAL VENUE',
    'Synthetic stadium for VSP testing only; not available for real bookings.',
    CASE WHEN i%3=0 THEN 7 ELSE 5 END,CASE WHEN i%3=0 THEN 14 ELSE 10 END)
  ON CONFLICT (id) DO NOTHING;
 END LOOP;
 FOR i IN 1..10 LOOP
  tid := md5('vsp-aswan-demo-team-'||i)::uuid;
  uid := md5('vsp-aswan-demo-user-'||(1+(i-1)*10))::uuid;
  INSERT INTO public.teams(id,name,captain_id,captain_name,governorate,sport_type,bio,
    points,wins,draws,losses,matches_played,is_official,verified_badge)
  VALUES(tid,'[DEMO] فريق أسوان '||lpad(i::text,2,'0'),
    uid,'[DEMO] كابتن '||i,'Aswan','Football',
    'STAGING ONLY - synthetic Aswan team',0,0,0,0,0,false,false)
  ON CONFLICT (id) DO NOTHING;
  FOR j IN 1..10 LOOP
   uid := md5('vsp-aswan-demo-user-'||((i-1)*10+j))::uuid;
   INSERT INTO public.team_members(team_id,user_id) VALUES(tid,uid)
   ON CONFLICT (team_id,user_id) DO NOTHING;
  END LOOP;
 END LOOP;
 SELECT id INTO tournament_id FROM public.vsp_1v1_tournaments
 WHERE name='[DEMO/STAGING] بطولة أسوان 1 ضد 1' AND governorate='Aswan' LIMIT 1;
 IF tournament_id IS NULL THEN
  INSERT INTO public.vsp_1v1_tournaments(name,target_player_count,status,governorate,entry_fee,prize_pool,prize_amount)
  VALUES('[DEMO/STAGING] بطولة أسوان 1 ضد 1',16,'draft','Aswan',0,0,0)
  RETURNING id INTO tournament_id;
 END IF;
 FOR i IN 1..16 LOOP
  uid := md5('vsp-aswan-demo-user-'||i)::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.vsp_1v1_tournament_players p
    WHERE p.tournament_id=tournament_id AND p.user_id=uid) THEN
   INSERT INTO public.vsp_1v1_tournament_players(tournament_id,user_id,player_name,payment_status,paid_amount)
   VALUES(tournament_id,uid,'[DEMO] لاعب أسوان '||lpad(i::text,3,'0'),'unpaid',0);
  END IF;
 END LOOP;
 -- Simulated completed matches; no paid orders, no payment gateway operations.
 FOR i IN 1..20 LOOP
  booking_id := md5('vsp-aswan-demo-match-'||i)::uuid;
  home_id := md5('vsp-aswan-demo-team-'||(1+(i-1)%10))::uuid;
  away_id := md5('vsp-aswan-demo-team-'||(1+i%10))::uuid;
  sid := md5('vsp-aswan-demo-stadium-'||(1+(i-1)%15))::uuid;
  home_goals := (i*3)%6;
  away_goals := (i*2+1)%5;
  home_name := '[DEMO] فريق أسوان '||lpad((1+(i-1)%10)::text,2,'0');
  away_name := '[DEMO] فريق أسوان '||lpad((1+i%10)::text,2,'0');
  INSERT INTO public.bookings(id,stadium_id,stadium_name,owner_id,created_by_user_id,
    start_time,end_time,total_price,status,booking_type,player_team_id,opponent_team_id,
    player_team_name,opponent_team_name,home_score,away_score,match_result_status,
    final_outcome,is_official_match,notes,elo_processed,challenge_status,
    payment_status,payment_reconcile_state,payment_source,is_paid)
  VALUES(booking_id,sid,'[DEMO] ملعب أسوان '||lpad((1+(i-1)%15)::text,2,'0'),
    md5('vsp-aswan-demo-user-'||(101+(i-1)%10))::uuid,
    md5('vsp-aswan-demo-user-'||(1+((i-1)%10)*10))::uuid,
    now()-((25-i)||' days')::interval,now()-((25-i)||' days')::interval+interval '1 hour',
    1,'completed','challenge',home_id,away_id,home_name,away_name,home_goals,away_goals,
    'confirmed',CASE WHEN home_goals>away_goals THEN 'homeWin'
                     WHEN home_goals<away_goals THEN 'awayWin' ELSE 'draw' END,
    false,'STAGING ONLY / DEMO MATCH / NOT A REAL BOOKING OR PAYMENT',true,'completed',
    'unpaid','unpaid','pending',false)
  ON CONFLICT (id) DO NOTHING;
 END LOOP;
 -- Demo-only leaderboard derived from the 20 synthetic results.
 WITH results AS (
  SELECT player_team_id AS team_id,
    sum(CASE WHEN home_score>away_score THEN 1 ELSE 0 END)::int AS wins,
    sum(CASE WHEN home_score=away_score THEN 1 ELSE 0 END)::int AS draws,
    sum(CASE WHEN home_score<away_score THEN 1 ELSE 0 END)::int AS losses,
    count(*)::int AS played FROM public.bookings
    WHERE notes='STAGING ONLY / DEMO MATCH / NOT A REAL BOOKING OR PAYMENT'
    GROUP BY player_team_id
  UNION ALL
  SELECT opponent_team_id,
    sum(CASE WHEN away_score>home_score THEN 1 ELSE 0 END)::int,
    sum(CASE WHEN home_score=away_score THEN 1 ELSE 0 END)::int,
    sum(CASE WHEN away_score<home_score THEN 1 ELSE 0 END)::int,
    count(*)::int FROM public.bookings
    WHERE notes='STAGING ONLY / DEMO MATCH / NOT A REAL BOOKING OR PAYMENT'
    GROUP BY opponent_team_id
 ), totals AS (
  SELECT team_id,sum(wins)::int wins,sum(draws)::int draws,
    sum(losses)::int losses,sum(played)::int played FROM results GROUP BY team_id
 )
 UPDATE public.teams t SET wins=s.wins,draws=s.draws,losses=s.losses,
   matches_played=s.played,points=s.wins*3+s.draws
 FROM totals s WHERE t.id=s.team_id AND t.name LIKE '[DEMO] فريق أسوان %';
END $seed$;