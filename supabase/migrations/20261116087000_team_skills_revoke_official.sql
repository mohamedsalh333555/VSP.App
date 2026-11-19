-- Revoke a single event official without blocking their global VSP account.
-- A row lock on the official assignment serializes revocation with in-flight
-- score/keeper operations: an operation finishing before revoke is audited,
-- and every later attempt is denied.
create or replace function public.team_skills_record_score(
 p_registration_id uuid,p_stage_no int,p_raw numeric)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype; p public.team_skills_phases%rowtype;
 v_id uuid; v_actor uuid := (select auth.uid());
begin
 if v_actor is null then raise exception 'Login required'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id;
 if r.id is null or r.status<>'approved' then raise exception 'Team not approved'; end if;
 if not vsp_skills_private.is_admin() then
   -- FOR SHARE serializes in-flight submission with assignment revocation.
   perform 1 from public.team_skills_officials o
    join public.users u on u.id=o.user_id
   where o.cup_id=r.cup_id and o.user_id=v_actor and o.role='judge'
     and coalesce(u.is_blocked,false)=false
   for share of o;
   if not found then raise exception 'Judge or admin only'; end if;
 end if;
 if not exists(select 1 from public.team_skills_cups c where c.id=r.cup_id and c.status='live')
 then raise exception 'Tournament not live'; end if;
 select * into p from public.team_skills_phases
 where cup_id=r.cup_id and stage_no=p_stage_no;
 if p.cup_id is null then raise exception 'Invalid stage'; end if;
 if exists(select 1 from public.team_skills_scores
  where registration_id=r.id and stage_no=p_stage_no) then
   raise exception 'Score exists; use audited correction route'; end if;
 insert into public.team_skills_scores(cup_id,registration_id,stage_no,raw_value,
  computed_points,entered_by)
 values(r.cup_id,r.id,p_stage_no,p_raw,
   vsp_skills_private.score(p.metric,p_raw,p.weight,p.target,p.best_ms,p.worst_ms),v_actor)
 returning id into v_id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(r.cup_id,v_actor,'submit_score',v_id,jsonb_build_object('stage',p_stage_no));
 return v_id;
end $$;

create or replace function public.team_skills_record_goalkeeper(
 p_trial_id uuid,p_shots int,p_saves int,p_conceded int)
returns void language plpgsql security definer set search_path='' as $$
declare t public.team_skills_goalkeeper_trials%rowtype;
begin
 select * into t from public.team_skills_goalkeeper_trials where id=p_trial_id for update;
 if t.id is null or t.status<>'scheduled' then raise exception 'Trial unavailable'; end if;
 if not vsp_skills_private.is_admin() then
   perform 1 from public.team_skills_officials o
     join public.users u on u.id=o.user_id
   where o.cup_id=t.cup_id and o.user_id=(select auth.uid())
     and o.role='judge' and coalesce(u.is_blocked,false)=false
   for share of o;
   if not found then raise exception 'Judge only'; end if;
 end if;
 if p_shots is null or p_shots < 1 or p_saves is null or p_conceded is null
    or p_saves < 0 or p_conceded < 0 or p_shots <> p_saves+p_conceded
 then raise exception 'Invalid goalkeeper measurements'; end if;
 update public.team_skills_goalkeeper_trials
 set shots_on_target=p_shots,saves=p_saves,goals_conceded=p_conceded,status='completed'
 where id=t.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(t.cup_id,(select auth.uid()),'record_goalkeeper',t.id,
 jsonb_build_object('shots',p_shots,'saves',p_saves,'conceded',p_conceded));
end $$;

create or replace function public.team_skills_revoke_official(
 p_cup_id uuid,p_user_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_prior_role text; v_actor uuid:=(select auth.uid());
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 if char_length(btrim(coalesce(p_reason,'')))<10
 then raise exception 'Documented revocation reason required'; end if;
 select o.role into v_prior_role from public.team_skills_officials o
 where o.cup_id=p_cup_id and o.user_id=p_user_id for update;
 if v_prior_role is null then raise exception 'Official assignment not found'; end if;

 delete from public.team_skills_officials
 where cup_id=p_cup_id and user_id=p_user_id;

 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(p_cup_id,v_actor,'revoke_official',p_user_id,
   jsonb_build_object('old_role',v_prior_role,'reason',btrim(p_reason)));

 insert into public.notifications(user_id,title,body,message,type,metadata)
 values(p_user_id,'تحديث تكليف تحكيم VSP',
   'تم إنهاء تكليفك في بطولة مهارات الفرق. تواصل مع الإدارة للاستفسار.',
   'تم إنهاء تكليفك في بطولة مهارات الفرق. تواصل مع الإدارة للاستفسار.',
   'info',jsonb_build_object(
     'source','team_skills_cup','event','official_revoked',
     'cup_id',p_cup_id,'role',v_prior_role));
end $$;
revoke all on function public.team_skills_revoke_official(uuid,uuid,text)
 from public,anon;
grant execute on function public.team_skills_revoke_official(uuid,uuid,text)
 to authenticated;
