CREATE OR REPLACE FUNCTION public.create_team_atomic(p_data jsonb,p_member_uids uuid[] DEFAULT ARRAY[]::uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_team_id uuid; v_caller uuid:=auth.uid(); v_count int; v_name text;
BEGIN
 IF v_caller IS NULL THEN RETURN jsonb_build_object('success',false,'error','Authentication required'); END IF;
 v_count:=coalesce(array_length(p_member_uids,1),0); v_name:=trim(coalesce(p_data->>'name',''));
 IF v_count<1 OR v_count>12 THEN RETURN jsonb_build_object('success',false,'error','Team members must be between 1 and 12'); END IF;
 IF cardinality(ARRAY(SELECT DISTINCT x FROM unnest(p_member_uids) x))<>v_count THEN RETURN jsonb_build_object('success',false,'error','Duplicate team member'); END IF;
 IF p_member_uids[1]<>v_caller THEN RETURN jsonb_build_object('success',false,'error','Only the captain can create the team'); END IF;
 IF v_name='' THEN RETURN jsonb_build_object('success',false,'error','Team name is required'); END IF;
 IF EXISTS(SELECT 1 FROM public.teams WHERE lower(trim(name))=lower(v_name)) THEN RETURN jsonb_build_object('success',false,'error','Team name already exists'); END IF;
 IF EXISTS(SELECT 1 FROM public.team_members WHERE user_id=ANY(p_member_uids) GROUP BY user_id HAVING count(*)>=3) THEN RETURN jsonb_build_object('success',false,'error','A player has reached the maximum of 3 teams'); END IF;
 INSERT INTO public.teams(name,bio,captain_id,logo_url,primary_color,secondary_color,city,governorate,preferred_formation,elo_rating,points,wins,draws,losses,matches_played,current_winning_streak,championships_won,is_active,is_blocked,is_verified)
 VALUES(v_name,coalesce(p_data->>'bio',''),v_caller,p_data->>'logo_url',coalesce(p_data->>'primary_color','#FFFFFF'),coalesce(p_data->>'secondary_color','#000000'),p_data->>'city',coalesce(p_data->>'governorate','Cairo'),coalesce(p_data->>'preferred_formation','2-2-1'),1200,0,0,0,0,0,0,0,true,false,false) RETURNING id INTO v_team_id;
 INSERT INTO public.team_members(team_id,user_id) SELECT v_team_id,x FROM unnest(p_member_uids) x;
 RETURN jsonb_build_object('success',true,'team_id',v_team_id);
END $$;

CREATE OR REPLACE FUNCTION public.add_team_member_atomic(p_team_id uuid,p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_role text; v_exists boolean;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('success',false,'error','Authentication required'); END IF;
 SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
 IF NOT EXISTS(SELECT 1 FROM public.teams WHERE id=p_team_id AND (captain_id=auth.uid() OR v_role IN ('admin','co_founder','cofounder','super_admin'))) THEN RETURN jsonb_build_object('success',false,'error','Unauthorized'); END IF;
 PERFORM 1 FROM public.teams WHERE id=p_team_id FOR UPDATE;
 SELECT EXISTS(SELECT 1 FROM public.team_members WHERE team_id=p_team_id AND user_id=p_user_id) INTO v_exists;
 IF v_exists THEN RETURN jsonb_build_object('success',true,'already_member',true); END IF;
 IF (SELECT count(*) FROM public.team_members WHERE team_id=p_team_id)>=12 THEN RETURN jsonb_build_object('success',false,'error','Team is full'); END IF;
 IF (SELECT count(*) FROM public.team_members WHERE user_id=p_user_id)>=3 THEN RETURN jsonb_build_object('success',false,'error','Player reached maximum teams'); END IF;
 INSERT INTO public.team_members(team_id,user_id) VALUES(p_team_id,p_user_id);
 RETURN jsonb_build_object('success',true);
END $$;
