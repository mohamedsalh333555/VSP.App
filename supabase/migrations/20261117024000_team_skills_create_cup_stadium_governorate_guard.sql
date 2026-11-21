-- Team Skills Cup source-only new migration, staging first.
-- Preserve the existing admin-created draft, all 12 phases, audit and award logic.
-- Venue governorate is authoritative; no user-record, subscription or booking mutation.
create or replace function public.team_skills_create_cup(
 p_name text,p_governorate text,p_stadium_id uuid,p_start timestamptz,p_end timestamptz,
 p_max_teams int default 8,p_hospitality_fee numeric default 50,
 p_prizes jsonb default '[]'::jsonb,p_image_url text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_stadium_governorate text;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 -- Resolve the canonical stadium governorate on the server; never trust a
 -- client-supplied cup region when the selected venue is in another region.
 select nullif(btrim(s.governorate),'') into v_stadium_governorate
 from public.stadiums s where s.id=p_stadium_id;
 if v_stadium_governorate is null or
    p_governorate is null or
    lower(btrim(p_governorate))<>lower(v_stadium_governorate)
 then raise exception 'Stadium governorate mismatch'; end if;
 if p_prizes is null or jsonb_typeof(p_prizes)<>'array' then raise exception 'Invalid prizes'; end if;
 insert into public.team_skills_cups(name,governorate,stadium_id,starts_at,ends_at,max_teams,
   hospitality_fee,prizes,image_url,created_by)
 values(p_name,v_stadium_governorate,p_stadium_id,p_start,p_end,p_max_teams,
   p_hospitality_fee,p_prizes,p_image_url,(select auth.uid())) returning id into v_id;
 insert into public.team_skills_phases(cup_id,stage_no,code,name_ar,category,weight,metric,target,best_ms,worst_ms)
 values
 (v_id,1,'attack_defence_a','الهجوم والدفاع — 1','attack_defence',12.5,'count',10,null,null),
 (v_id,2,'attack_defence_b','الهجوم والدفاع — 2','attack_defence',12.5,'count',10,null,null),
 (v_id,3,'moving_shots_a','التسديد المتحرك — 1','moving_shots',7.5,'count',10,null,null),
 (v_id,4,'moving_shots_b','التسديد المتحرك — 2','moving_shots',7.5,'count',10,null,null),
 (v_id,5,'penalties_a','ركلات الجزاء — 1','penalties',5,'count',10,null,null),
 (v_id,6,'penalties_b','ركلات الجزاء — 2','penalties',5,'count',10,null,null),
 (v_id,7,'agility_a','السرعة والرشاقة — 1','agility',7.5,'time_ms',null,30000,60000),
 (v_id,8,'agility_b','السرعة والرشاقة — 2','agility',7.5,'time_ms',null,30000,60000),
 (v_id,9,'passing_a','التمرير والتحكم — 1','passing',7.5,'count',10,null,null),
 (v_id,10,'passing_b','التمرير والتحكم — 2','passing',7.5,'count',10,null,null),
 (v_id,11,'transition_a','التحول الدفاعي والهجومي — 1','transition',10,'count',10,null,null),
 (v_id,12,'transition_b','التحول الدفاعي والهجومي — 2','transition',10,'count',10,null,null);
 insert into public.team_skills_audit(cup_id,actor_id,action)
 values(v_id,(select auth.uid()),'create_cup');
 return v_id;
end $$;
revoke all on function public.team_skills_create_cup(
 text,text,uuid,timestamptz,timestamptz,int,numeric,jsonb,text)
 from public,anon;
grant execute on function public.team_skills_create_cup(
 text,text,uuid,timestamptz,timestamptz,int,numeric,jsonb,text)
 to authenticated;
