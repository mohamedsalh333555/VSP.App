CREATE OR REPLACE FUNCTION public.leave_championship_atomic(p_championship_id uuid,p_team_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_champ record; v_team record; v_role text; v_paid boolean;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('success',false,'error','Authentication required'); END IF;
 SELECT * INTO v_champ FROM public.championships WHERE id=p_championship_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','Championship not found'); END IF;
 SELECT * INTO v_team FROM public.teams WHERE id=p_team_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','Team not found'); END IF;
 SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
 IF v_team.captain_id IS DISTINCT FROM auth.uid() AND v_champ.owner_id IS DISTINCT FROM auth.uid() AND coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','Unauthorized'); END IF;
 IF NOT (p_team_id=ANY(coalesce(v_champ.joined_teams,ARRAY[]::uuid[]))) THEN RETURN jsonb_build_object('success',false,'error','Team is not registered'); END IF;
 IF v_champ.status<>'open' THEN RETURN jsonb_build_object('success',false,'error','Cannot leave after registration has closed'); END IF;
 SELECT EXISTS(SELECT 1 FROM public.tournament_orders WHERE championship_id=p_championship_id AND team_id=p_team_id AND payment_status='paid') INTO v_paid;
 IF v_paid THEN RETURN jsonb_build_object('success',false,'error','PAID_TEAM_REFUND_REQUIRED: A paid team cannot leave without a refund flow'); END IF;
 UPDATE public.championships SET joined_teams=array_remove(coalesce(joined_teams,ARRAY[]::uuid[]),p_team_id),paid_teams=array_remove(coalesce(paid_teams,ARRAY[]::uuid[]),p_team_id),updated_at=timezone('utc',now()) WHERE id=p_championship_id;
 UPDATE public.tournament_orders SET payment_status='cancelled_withdrawal',updated_at=timezone('utc',now()) WHERE championship_id=p_championship_id AND team_id=p_team_id AND payment_status='pending';
 RETURN jsonb_build_object('success',true,'championship_id',p_championship_id,'team_id',p_team_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.crown_tournament_champion_atomic(p_championship_id uuid,p_champion_team_id uuid,p_champion_team_name text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_champ record; v_role text; v_team_name text; v_prize numeric; v_trophy_title text; v_now timestamptz:=timezone('utc',now()); v_member record; v_awarded int:=0;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
 SELECT * INTO v_champ FROM public.championships WHERE id=p_championship_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Championship not found'; END IF;
 SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
 IF v_champ.owner_id IS DISTINCT FROM auth.uid() AND coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
 IF v_champ.status NOT IN ('ongoing','completed') THEN RAISE EXCEPTION 'Championship is not ready for champion'; END IF;
 IF NOT (p_champion_team_id=ANY(coalesce(v_champ.joined_teams,ARRAY[]::uuid[]))) OR NOT (p_champion_team_id=ANY(coalesce(v_champ.paid_teams,ARRAY[]::uuid[]))) THEN RAISE EXCEPTION 'Champion team must be registered and paid'; END IF;
 SELECT name INTO v_team_name FROM public.teams WHERE id=p_champion_team_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Champion team not found'; END IF;
 IF v_champ.status='completed' AND v_champ.champion_team_id=p_champion_team_id THEN RETURN jsonb_build_object('success',true,'already_crowned',true,'champion_team_id',p_champion_team_id); END IF;
 v_prize:=coalesce(nullif(v_champ.prize_pool,0),v_champ.grand_prize,0); v_trophy_title:='بطل بطولة '||coalesce(v_champ.name,'VSP');
 UPDATE public.championships SET status='completed',champion_team_id=p_champion_team_id,champion_team_name=v_team_name,winner_team_id=p_champion_team_id,winner_team_name=v_team_name,updated_at=v_now WHERE id=p_championship_id;
 UPDATE public.teams SET championships_won=coalesce(championships_won,0)+1,points=coalesce(points,0)+100,updated_at=v_now WHERE id=p_champion_team_id;
 FOR v_member IN SELECT user_id FROM public.team_members WHERE team_id=p_champion_team_id LOOP
   IF NOT EXISTS(SELECT 1 FROM public.player_trophies WHERE user_id=v_member.user_id AND championship_id=p_championship_id) THEN
     INSERT INTO public.player_trophies(id,user_id,championship_id,title,prize_won,created_at) VALUES(gen_random_uuid(),v_member.user_id,p_championship_id,v_trophy_title,v_prize,v_now);
     v_awarded:=v_awarded+1;
   END IF;
 END LOOP;
 RETURN jsonb_build_object('success',true,'champion_team_id',p_champion_team_id,'championship_id',p_championship_id,'trophies_awarded',v_awarded,'prize_per_trophy',v_prize);
END;
$$;
