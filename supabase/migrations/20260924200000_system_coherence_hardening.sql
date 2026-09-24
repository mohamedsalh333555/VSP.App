-- VSP system-coherence hardening
BEGIN;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS bio text;
UPDATE public.platform_fee_config SET booking_vsp_rate=.02,booking_paymob_local_rate=.0275,booking_paymob_wallet_rate=.0275,booking_paymob_foreign_rate=.0275,booking_paymob_fixed_fee=3,vsp_applies_to_cash=false,paymob_applies_to_electronic=true,updated_at=timezone('utc',now()) WHERE id=1;

CREATE OR REPLACE FUNCTION public.prevent_late_cancellation() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_role text;
BEGIN
 IF NEW.status='cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' AND OLD.status<>'pending'
    AND now()>OLD.start_time-((SELECT player_cancellation_cutoff_hours FROM public.platform_business_rules WHERE id=1)*interval '1 hour')
    AND now()>OLD.created_at+((SELECT player_cancellation_grace_minutes FROM public.platform_business_rules WHERE id=1)*interval '1 minute')
    AND auth.uid() IS DISTINCT FROM OLD.owner_id THEN
   SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
   IF coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin','service_role') AND current_user NOT IN ('postgres','service_role')
   THEN RAISE EXCEPTION 'cannot_cancel_within_6_hours'; END IF;
 END IF; RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.submit_stadium_review_atomic(p_stadium_id uuid,p_user_id uuid,p_user_name text,p_user_image_url text,p_rating integer,p_comment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_owner uuid; v_allowed boolean;
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' AND p_user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('success',false,'error','Unauthorized: You cannot submit reviews on behalf of another user'); END IF;
 IF p_rating<1 OR p_rating>5 THEN RETURN jsonb_build_object('success',false,'error','Rating must be between 1 and 5'); END IF;
 SELECT owner_id INTO v_owner FROM public.stadiums WHERE id=p_stadium_id;
 IF v_owner IS NULL THEN RETURN jsonb_build_object('success',false,'error','الملعب غير موجود.'); END IF;
 IF v_owner=p_user_id THEN RETURN jsonb_build_object('success',false,'error','cannot_review_own_stadium'); END IF;
 SELECT EXISTS(SELECT 1 FROM public.bookings b WHERE b.stadium_id=p_stadium_id AND b.status='completed'
  AND (b.created_by_user_id=p_user_id OR b.user_id=p_user_id OR EXISTS(SELECT 1 FROM public.booking_players bp WHERE bp.booking_id=b.id AND bp.user_id=p_user_id))) INTO v_allowed;
 IF NOT v_allowed THEN RETURN jsonb_build_object('success',false,'error','must_have_completed_booking'); END IF;
 INSERT INTO public.reviews(stadium_id,user_id,user_name,user_image_url,rating,review_text,created_at)
 VALUES(p_stadium_id,p_user_id,p_user_name,p_user_image_url,p_rating,p_comment,timezone('utc',now()))
 ON CONFLICT(stadium_id,user_id) DO UPDATE SET rating=excluded.rating,review_text=excluded.review_text,user_name=excluded.user_name,user_image_url=excluded.user_image_url,created_at=timezone('utc',now());
 UPDATE public.stadiums SET rating=(SELECT round(avg(r.rating)::numeric,1) FROM public.reviews r WHERE r.stadium_id=p_stadium_id),reviews_count=(SELECT count(*) FROM public.reviews r WHERE r.stadium_id=p_stadium_id),updated_at=timezone('utc',now()) WHERE id=p_stadium_id;
 RETURN jsonb_build_object('success',true,'stadium_id',p_stadium_id,'rating',p_rating);
END; $$;

CREATE OR REPLACE FUNCTION public.join_championship_atomic(p_championship_id uuid,p_team_id uuid,p_is_paid boolean DEFAULT false,p_player_ids uuid[] DEFAULT ARRAY[]::uuid[],p_guest_names text[] DEFAULT ARRAY[]::text[],p_total_paid_amount numeric DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_champ record; v_team record; v_role text; v_count integer; v_req integer; v_joined integer;
BEGIN
 IF auth.uid() IS NULL AND coalesce(auth.role(),'')<>'service_role' THEN RETURN jsonb_build_object('success',false,'error','يجب تسجيل الدخول أولاً للانضمام للبطولة.'); END IF;
 SELECT * INTO v_champ FROM public.championships WHERE id=p_championship_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','البطولة غير موجودة.'); END IF;
 IF v_champ.status<>'open' THEN RETURN jsonb_build_object('success',false,'error','انتهى التسجيل في هذه البطولة أو أنها لم تبدأ بعد.'); END IF;
 SELECT * INTO v_team FROM public.teams WHERE id=p_team_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','الفريق غير موجود.'); END IF;
 IF coalesce(auth.role(),'')<>'service_role' THEN
   SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
   IF v_team.captain_id IS DISTINCT FROM auth.uid() AND coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') AND v_champ.owner_id IS DISTINCT FROM auth.uid()
   THEN RETURN jsonb_build_object('success',false,'error','فقط كابتن الفريق أو منظم البطولة يمكنه تسجيل الفريق.'); END IF;
 END IF;
 IF p_team_id=ANY(coalesce(v_champ.joined_teams,ARRAY[]::uuid[])) THEN RETURN jsonb_build_object('success',false,'error','هذا الفريق مسجل في البطولة بالفعل.'); END IF;
 v_joined:=coalesce(array_length(v_champ.joined_teams,1),0);
 IF v_joined>=v_champ.max_teams THEN RETURN jsonb_build_object('success',false,'error','البطولة مكتملة العدد. لا يمكن إضافة فرق جديدة.'); END IF;
 v_req:=greatest(coalesce(v_champ.min_players_per_team,1),1);
 SELECT count(*) INTO v_count FROM public.team_members WHERE team_id=p_team_id;
 IF v_count<v_req THEN RETURN jsonb_build_object('success',false,'error','team_roster_incomplete','required_players',v_req,'current_players',v_count); END IF;
 UPDATE public.championships SET joined_teams=array_append(coalesce(joined_teams,ARRAY[]::uuid[]),p_team_id),paid_teams=CASE WHEN p_is_paid THEN array_append(coalesce(paid_teams,ARRAY[]::uuid[]),p_team_id) ELSE coalesce(paid_teams,ARRAY[]::uuid[]) END,updated_at=timezone('utc',now()) WHERE id=p_championship_id;
 RETURN jsonb_build_object('success',true,'message','تم تسجيل الفريق في البطولة بنجاح.','is_paid',p_is_paid,'joined_teams_count',v_joined+1);
END; $$;
GRANT EXECUTE ON FUNCTION public.submit_stadium_review_atomic(uuid,uuid,text,text,integer,text) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.join_championship_atomic(uuid,uuid,boolean,uuid[],text[],numeric) TO authenticated,service_role;
REVOKE EXECUTE ON FUNCTION public.submit_stadium_review_atomic(uuid,uuid,text,text,integer,text) FROM anon,public;
REVOKE EXECUTE ON FUNCTION public.join_championship_atomic(uuid,uuid,boolean,uuid[],text[],numeric) FROM anon,public;
COMMIT;