-- Narrow follow-up: let real team members see their entry; central 100-point
-- phase configuration remains administrator-only and locked once scoring begins.
create policy "team_skills_member_registration_status" on public.team_skills_registrations
for select to authenticated using (
 exists(select 1 from public.team_members m
   where m.team_id=team_id and m.user_id=(select auth.uid()))
);

create or replace function public.team_skills_configure_phases(
 p_cup_id uuid, p_updates jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare item jsonb; v_stage int; seen int[]:=array[]::int[];
 v_count int; v_total numeric;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 perform 1 from public.team_skills_cups where id=p_cup_id and status='draft' for update;
 if not found then raise exception 'Only draft phases can be changed'; end if;
 if jsonb_typeof(p_updates)<>'array' or jsonb_array_length(p_updates)<>12
 then raise exception 'Exactly 12 phase configurations required'; end if;
 if exists(select 1 from public.team_skills_scores where cup_id=p_cup_id)
 then raise exception 'Scores already exist'; end if;
 for item in select value from jsonb_array_elements(p_updates) loop
   if (item->>'stage_no') is null or (item->>'weight') is null then
     raise exception 'Missing stage number or weight';
   end if;
   v_stage:=(item->>'stage_no')::int;
   if v_stage<1 or v_stage>12 or v_stage=any(seen)
   then raise exception 'Invalid or duplicate stage'; end if;
   seen:=array_append(seen,v_stage);
   update public.team_skills_phases
   set weight=(item->>'weight')::numeric,
       target=case when metric='count' then coalesce((item->>'target')::numeric,target) else null end,
       best_ms=case when metric='time_ms' then coalesce((item->>'best_ms')::int,best_ms) else null end,
       worst_ms=case when metric='time_ms' then coalesce((item->>'worst_ms')::int,worst_ms) else null end
   where cup_id=p_cup_id and stage_no=v_stage;
   if not found then raise exception 'Unknown stage'; end if;
 end loop;
 select count(*),sum(weight) into v_count,v_total
 from public.team_skills_phases where cup_id=p_cup_id;
 if v_count<>12 or v_total<>100 then raise exception 'Total phase weights must be 100'; end if;
 insert into public.team_skills_audit(cup_id,actor_id,action,details)
 values(p_cup_id,(select auth.uid()),'configure_phases',
 jsonb_build_object('updated_stages',12,'total',100));
end $$;
revoke all on function public.team_skills_configure_phases(uuid,jsonb) from public,anon;
grant execute on function public.team_skills_configure_phases(uuid,jsonb) to authenticated;

create or replace function vsp_skills_private.check_cup_activation()
returns trigger language plpgsql security definer set search_path='' as $$
declare approved_count int;
begin
 if new.status='live' and old.status is distinct from new.status then
   select count(*) into approved_count
   from public.team_skills_registrations r
   where r.cup_id=new.id and r.status='approved';
   if approved_count<4 or approved_count>new.max_teams then
     raise exception 'Live cup requires 4 to max_teams approved teams';
   end if;
 end if;
 return new;
end $$;
drop trigger if exists team_skills_cup_activation_gate on public.team_skills_cups;
create trigger team_skills_cup_activation_gate
before update of status on public.team_skills_cups
for each row execute function vsp_skills_private.check_cup_activation();
revoke all on function vsp_skills_private.check_cup_activation() from public,anon;
