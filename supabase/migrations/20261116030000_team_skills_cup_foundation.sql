-- Team Skills Cup: additive foundation, leaves historical 1v1, bookings and subscriptions intact.
-- Staging first. Do not deploy to production without role/JWT/concurrency acceptance.
create schema if not exists vsp_skills_private;

create or replace function vsp_skills_private.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.users u where u.id = (select auth.uid())
      and u.role = 'admin' and coalesce(u.is_blocked,false) = false
  )
$$;
revoke all on function vsp_skills_private.is_admin() from public, anon;
grant usage on schema vsp_skills_private to authenticated;
grant execute on function vsp_skills_private.is_admin() to authenticated;

create table if not exists public.team_skills_cups (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(btrim(name)) between 3 and 120),
 governorate text not null,
 stadium_id uuid not null references public.stadiums(id),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 max_teams integer not null default 8 check(max_teams between 4 and 8),
 hospitality_fee numeric(10,2) not null default 50 check(hospitality_fee >= 0),
 status text not null default 'draft' check(status in ('draft','registration','live','completed','cancelled')),
 image_url text,
 prizes jsonb not null default '[]'::jsonb check(jsonb_typeof(prizes)='array'),
 created_by uuid not null references public.users(id),
 created_at timestamptz not null default now(),
 published_at timestamptz,
 check(ends_at > starts_at and ends_at <= starts_at + interval '3 hours'
       and ends_at >= starts_at + interval '2 hours')
);
create table if not exists public.team_skills_phases (
 cup_id uuid not null references public.team_skills_cups(id) on delete cascade,
 stage_no integer not null check(stage_no between 1 and 12),
 code text not null,
 name_ar text not null,
 category text not null,
 weight numeric(6,2) not null check(weight > 0 and weight <= 25),
 metric text not null check(metric in ('count','time_ms')),
 target numeric(12,2),
 best_ms integer,
 worst_ms integer,
 primary key (cup_id,stage_no),
 unique(cup_id,code),
 check((metric = 'count' and target > 0 and best_ms is null and worst_ms is null)
       or (metric = 'time_ms' and best_ms > 0 and worst_ms > best_ms and target is null))
);
create table if not exists public.team_skills_registrations (
 id uuid primary key default gen_random_uuid(),
 cup_id uuid not null references public.team_skills_cups(id),
 team_id uuid not null references public.teams(id),
 captain_id uuid not null references public.users(id),
 goalkeeper_id uuid not null references public.users(id),
 representative_id uuid not null references public.users(id),
 status text not null default 'pending' check(status in ('pending','approved','rejected','waitlist','withdrawn')),
 hospitality_payment_status text not null default 'unpaid'
   check(hospitality_payment_status in ('unpaid','verified','waived')),
 rejection_reason text,
 checked_in_at timestamptz,
 created_at timestamptz not null default now(),
 reviewed_by uuid references public.users(id),
 reviewed_at timestamptz,
 unique(cup_id,team_id),
 unique(id,cup_id)
);
create table if not exists public.team_skills_roster (
 cup_id uuid not null,
 registration_id uuid not null,
 player_id uuid not null references public.users(id),
 position text not null check(position in ('field','goalkeeper')),
 active boolean not null default true,
 primary key (registration_id,player_id),
 foreign key (registration_id,cup_id)
   references public.team_skills_registrations(id,cup_id)
);
create unique index if not exists team_skills_roster_one_active_player
 on public.team_skills_roster(cup_id,player_id) where active;

create table if not exists public.team_skills_officials (
 cup_id uuid not null references public.team_skills_cups(id),
 user_id uuid not null references public.users(id),
 role text not null check(role in ('judge','organizer')),
 assigned_by uuid not null references public.users(id),
 primary key (cup_id,user_id)
);
create table if not exists public.team_skills_scores (
 id uuid primary key default gen_random_uuid(),
 cup_id uuid not null,
 registration_id uuid not null,
 stage_no integer not null,
 raw_value numeric(12,2) not null check(raw_value >= 0),
 computed_points numeric(6,2) not null check(computed_points between 0 and 25),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 entered_by uuid not null references public.users(id),
 approved_by uuid references public.users(id),
 entered_at timestamptz not null default now(),
 approved_at timestamptz,
 foreign key (cup_id,stage_no) references public.team_skills_phases(cup_id,stage_no),
 foreign key (registration_id,cup_id) references public.team_skills_registrations(id,cup_id),
 unique(registration_id,stage_no)
);
create table if not exists public.team_skills_audit (
 id bigint generated always as identity primary key,
 cup_id uuid not null references public.team_skills_cups(id),
 actor_id uuid not null references public.users(id),
 action text not null,
 subject_id uuid,
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create table if not exists public.team_skills_awards (
 cup_id uuid not null references public.team_skills_cups(id),
 award_type text not null check(award_type in ('team_champion','one_v_one_champion','best_goalkeeper')),
 team_id uuid not null references public.teams(id),
 player_id uuid references public.users(id),
 announced_by uuid not null references public.users(id),
 announced_at timestamptz not null default now(),
 primary key (cup_id,award_type),
 check((award_type='team_champion' and player_id is null)
       or (award_type <> 'team_champion' and player_id is not null))
);
create table if not exists public.team_skills_goalkeeper_trials (
 id uuid primary key default gen_random_uuid(),
 cup_id uuid not null references public.team_skills_cups(id),
 goalkeeper_id uuid not null references public.users(id),
 opponent_team_id uuid not null references public.teams(id),
 registration_id uuid not null references public.team_skills_registrations(id),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 shots_on_target integer not null default 0 check(shots_on_target >= 0),
 saves integer not null default 0 check(saves >= 0),
 goals_conceded integer not null default 0 check(goals_conceded >= 0),
 status text not null default 'scheduled' check(status in ('scheduled','completed','approved')),
 check(ends_at > starts_at),
 check(saves + goals_conceded <= shots_on_target)
);
create table if not exists public.team_skills_knockout (
 id uuid primary key default gen_random_uuid(),
 cup_id uuid not null references public.team_skills_cups(id),
 round_no integer not null check(round_no between 1 and 3),
 match_no integer not null check(match_no between 1 and 4),
 first_registration_id uuid references public.team_skills_registrations(id),
 second_registration_id uuid references public.team_skills_registrations(id),
 first_goals integer check(first_goals >= 0),
 second_goals integer check(second_goals >= 0),
 winner_registration_id uuid references public.team_skills_registrations(id),
 status text not null default 'scheduled' check(status in ('scheduled','approved')),
 unique(cup_id,round_no,match_no),
 check(first_registration_id is distinct from second_registration_id)
);
-- Read-only by default. Mutation requires narrowly scoped, guarded RPCs.
do $$
declare t text;
begin
 foreach t in array array['team_skills_cups','team_skills_phases','team_skills_registrations',
 'team_skills_roster','team_skills_officials','team_skills_scores','team_skills_audit',
 'team_skills_awards','team_skills_goalkeeper_trials','team_skills_knockout']
 loop
   execute format('alter table public.%I enable row level security',t);
   execute format('revoke all on public.%I from public, anon, authenticated',t);
   execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create policy "published_cups_or_admin" on public.team_skills_cups
 for select to authenticated using (status <> 'draft' or vsp_skills_private.is_admin());
create policy "phases_for_visible_cups" on public.team_skills_phases
 for select to authenticated using (
  exists(select 1 from public.team_skills_cups c where c.id=cup_id));
create policy "registration_own_or_public_approved" on public.team_skills_registrations
 for select to authenticated using(
  vsp_skills_private.is_admin() or captain_id=(select auth.uid()) or
  (status='approved' and exists(select 1 from public.team_skills_cups c where c.id=cup_id and c.status <> 'draft'))
 );
create policy "roster_own_or_admin" on public.team_skills_roster
 for select to authenticated using (
  vsp_skills_private.is_admin() or exists(
    select 1 from public.team_skills_registrations r
    where r.id=registration_id and r.captain_id=(select auth.uid()))
 );
create policy "official_own_or_admin" on public.team_skills_officials
 for select to authenticated using(user_id=(select auth.uid()) or vsp_skills_private.is_admin());
create policy "score_approved_or_official" on public.team_skills_scores
 for select to authenticated using (
  (status='approved' and exists(select 1 from public.team_skills_cups c where c.id=cup_id and c.status <> 'draft'))
  or vsp_skills_private.is_admin()
  or exists(select 1 from public.team_skills_officials o where o.cup_id=cup_id and o.user_id=(select auth.uid()))
 );
create policy "audit_admin_only" on public.team_skills_audit
 for select to authenticated using(vsp_skills_private.is_admin());
create policy "awards_visible" on public.team_skills_awards
 for select to authenticated using(exists(
  select 1 from public.team_skills_cups c where c.id=cup_id and c.status='completed'
 ));
create policy "goalkeeper_trial_official" on public.team_skills_goalkeeper_trials
 for select to authenticated using (vsp_skills_private.is_admin() or exists(
  select 1 from public.team_skills_officials o where o.cup_id=cup_id and o.user_id=(select auth.uid())
 ));
create policy "knockout_published" on public.team_skills_knockout
 for select to authenticated using(exists(
  select 1 from public.team_skills_cups c where c.id=cup_id and c.status <> 'draft'
 ));
create or replace view public.team_skills_leaderboard with (security_invoker=true) as
select r.cup_id, r.team_id, r.id as registration_id,
       coalesce(sum(s.computed_points) filter (where s.status='approved'),0)::numeric(7,2) as points,
       count(s.id) filter (where s.status='approved')::integer as completed_stages,
       (count(s.id) filter (where s.status='approved')=12) as all_stages_approved
from public.team_skills_registrations r
left join public.team_skills_scores s on s.registration_id=r.id and s.cup_id=r.cup_id
where r.status='approved'
group by r.cup_id,r.team_id,r.id;
revoke all on public.team_skills_leaderboard from public, anon;
grant select on public.team_skills_leaderboard to authenticated;

-- Configurable, objective measurement. This is the canonical score authority.
create or replace function vsp_skills_private.score(p_metric text, p_raw numeric,
  p_weight numeric, p_target numeric, p_best integer, p_worst integer)
returns numeric language plpgsql immutable set search_path='' as $$
declare ratio numeric;
begin
 if p_raw is null or p_raw < 0 then raise exception 'Invalid raw score'; end if;
 if p_metric='count' then
   if p_raw <> trunc(p_raw) or p_target <= 0 or p_raw > p_target then
     raise exception 'Invalid success count';
   end if;
   ratio := p_raw/p_target;
 elsif p_metric='time_ms' then
   if p_raw <= 0 or p_best <= 0 or p_worst <= p_best then
     raise exception 'Invalid timing';
   end if;
   ratio := greatest(0,least(1,(p_worst-p_raw)/(p_worst-p_best)));
 else raise exception 'Unsupported metric'; end if;
 return round(p_weight*ratio,2);
end $$;
revoke all on function vsp_skills_private.score(text,numeric,numeric,numeric,integer,integer) from public,anon;
grant execute on function vsp_skills_private.score(text,numeric,numeric,numeric,integer,integer) to authenticated;

create or replace function public.team_skills_create_cup(
 p_name text,p_governorate text,p_stadium_id uuid,p_start timestamptz,p_end timestamptz,
 p_max_teams int default 8,p_hospitality_fee numeric default 50,
 p_prizes jsonb default '[]'::jsonb,p_image_url text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 if p_prizes is null or jsonb_typeof(p_prizes)<>'array' then raise exception 'Invalid prizes'; end if;
 insert into public.team_skills_cups(name,governorate,stadium_id,starts_at,ends_at,max_teams,
   hospitality_fee,prizes,image_url,created_by)
 values(p_name,p_governorate,p_stadium_id,p_start,p_end,p_max_teams,
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
revoke all on function public.team_skills_create_cup(text,text,uuid,timestamptz,timestamptz,int,numeric,jsonb,text) from public,anon;
grant execute on function public.team_skills_create_cup(text,text,uuid,timestamptz,timestamptz,int,numeric,jsonb,text) to authenticated;

create or replace function public.team_skills_set_status(p_cup_id uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare existing text;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select status into existing from public.team_skills_cups where id=p_cup_id for update;
 if existing is null or not (
  (existing='draft' and p_status in ('registration','cancelled')) or
  (existing='registration' and p_status in ('live','cancelled')) or
  (existing='live' and p_status in ('completed','cancelled'))
 ) then raise exception 'Invalid status transition'; end if;
 if p_status='completed' and exists(
   select 1 from public.team_skills_registrations r where r.cup_id=p_cup_id and r.status='approved'
   and (select count(*) from public.team_skills_scores s
      where s.registration_id=r.id and s.status='approved') <> 12
 ) then raise exception 'Incomplete approved stages'; end if;
 update public.team_skills_cups set status=p_status,
 published_at=case when existing='draft' and p_status='registration' then now() else published_at end
 where id=p_cup_id;
 insert into public.team_skills_audit(cup_id,actor_id,action,details)
 values(p_cup_id,(select auth.uid()),'change_status',jsonb_build_object('old',existing,'new',p_status));
end $$;
revoke all on function public.team_skills_set_status(uuid,text) from public,anon;
grant execute on function public.team_skills_set_status(uuid,text) to authenticated;

-- Row lock serializes the final slot. Existing team members must supply five UNIQUE players,
-- exactly one goalkeeper, and an actual captain; no payment flag is client writable.
create or replace function public.team_skills_register(
 p_cup_id uuid,p_team_id uuid,p_player_ids uuid[],p_goalkeeper_id uuid,p_representative_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_cup public.team_skills_cups%rowtype; v_reg uuid; v_actor uuid := (select auth.uid());
begin
 if v_actor is null then raise exception 'Login required'; end if;
 select * into v_cup from public.team_skills_cups where id=p_cup_id for update;
 if v_cup.id is null or v_cup.status <> 'registration' or v_cup.starts_at <= now()
 then raise exception 'Registration closed'; end if;
 if not exists(select 1 from public.teams where id=p_team_id and captain_id=v_actor)
 then raise exception 'Captain only'; end if;
 if coalesce(array_length(p_player_ids,1),0)<>5 or
    (select count(distinct x) from unnest(p_player_ids) as x)<>5 or
    p_goalkeeper_id is null or not (p_goalkeeper_id=any(p_player_ids)) or
    p_representative_id is null or not (p_representative_id=any(p_player_ids))
 then raise exception 'Exactly four field players and one goalkeeper required'; end if;
 if exists(select 1 from unnest(p_player_ids) as x
   where not exists(select 1 from public.team_members tm
     where tm.team_id=p_team_id and tm.user_id=x)
     and not exists(select 1 from public.teams t where t.id=p_team_id and t.captain_id=x)
 ) then raise exception 'Roster player is not a team member'; end if;
 if exists(select 1 from public.team_skills_registrations where cup_id=p_cup_id and team_id=p_team_id)
 then raise exception 'Team already registered'; end if;
 if exists(select 1 from public.team_skills_roster where cup_id=p_cup_id and active
    and player_id=any(p_player_ids))
 then raise exception 'Player is already participating'; end if;
 if (select count(*) from public.team_skills_registrations where cup_id=p_cup_id
   and status in ('pending','approved')) >= v_cup.max_teams
 then raise exception 'Tournament is full'; end if;
 insert into public.team_skills_registrations(cup_id,team_id,captain_id,goalkeeper_id,representative_id)
 values(p_cup_id,p_team_id,v_actor,p_goalkeeper_id,p_representative_id) returning id into v_reg;
 insert into public.team_skills_roster(cup_id,registration_id,player_id,position)
 select p_cup_id,v_reg,x,case when x=p_goalkeeper_id then 'goalkeeper' else 'field' end
 from unnest(p_player_ids) as x;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id)
 values(p_cup_id,v_actor,'register_team',v_reg);
 return v_reg;
end $$;
revoke all on function public.team_skills_register(uuid,uuid,uuid[],uuid,uuid) from public,anon;
grant execute on function public.team_skills_register(uuid,uuid,uuid[],uuid,uuid) to authenticated;

create or replace function public.team_skills_review_registration(
 p_registration_id uuid,p_decision text,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 if p_decision not in ('approved','rejected','waitlist') then raise exception 'Invalid decision'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id for update;
 if r.id is null or r.status not in ('pending','waitlist') then raise exception 'Not pending'; end if;
 if p_decision='rejected' and nullif(btrim(p_reason),'') is null then
   raise exception 'Rejection reason required';
 end if;
 update public.team_skills_registrations set status=p_decision,
  rejection_reason=case when p_decision='rejected' then p_reason else null end,
  reviewed_by=(select auth.uid()),reviewed_at=now()
 where id=r.id;
 if p_decision='rejected' then
   update public.team_skills_roster set active=false where registration_id=r.id;
 end if;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(r.cup_id,(select auth.uid()),'review_registration',r.id,jsonb_build_object('decision',p_decision,'reason',p_reason));
end $$;
revoke all on function public.team_skills_review_registration(uuid,text,text) from public,anon;
grant execute on function public.team_skills_review_registration(uuid,text,text) to authenticated;

create or replace function public.team_skills_record_score(
 p_registration_id uuid,p_stage_no int,p_raw numeric)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype; p public.team_skills_phases%rowtype;
 v_id uuid; v_actor uuid := (select auth.uid());
begin
 if v_actor is null then raise exception 'Login required'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id;
 if r.id is null or r.status<>'approved' then raise exception 'Team not approved'; end if;
 if not (vsp_skills_private.is_admin() or exists(
  select 1 from public.team_skills_officials o where o.cup_id=r.cup_id and o.user_id=v_actor and o.role='judge'))
 then raise exception 'Judge or admin only'; end if;
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
revoke all on function public.team_skills_record_score(uuid,int,numeric) from public,anon;
grant execute on function public.team_skills_record_score(uuid,int,numeric) to authenticated;

create or replace function public.team_skills_approve_score(p_score_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare s public.team_skills_scores%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into s from public.team_skills_scores where id=p_score_id for update;
 if s.id is null or s.status<>'pending' then raise exception 'Not pending'; end if;
 update public.team_skills_scores set status='approved',approved_by=(select auth.uid()),approved_at=now()
 where id=s.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(s.cup_id,(select auth.uid()),'approve_score',s.id,jsonb_build_object('points',s.computed_points));
end $$;
revoke all on function public.team_skills_approve_score(uuid) from public,anon;
grant execute on function public.team_skills_approve_score(uuid) to authenticated;
