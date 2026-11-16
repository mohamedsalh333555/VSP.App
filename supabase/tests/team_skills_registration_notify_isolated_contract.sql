-- Disposable SQL fixture for team-registration transactional notifications.
create schema vsp_skills_private;
create table public.team_skills_registrations(
 id uuid primary key, cup_id uuid not null,
 team_id uuid not null,captain_id uuid not null,status text not null);
create table public.notifications(
 id uuid primary key default gen_random_uuid(),user_id uuid not null,
 title text not null,body text not null,message text,
 type text not null,metadata jsonb,created_at timestamptz default now());
-- TEAM_SKILLS_NOTIFY_MIGRATION

insert into public.team_skills_registrations(id,cup_id,team_id,captain_id,status)
values
('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000301','pending'),
('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000302','pending'),
('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000303','pending');

update public.team_skills_registrations set status='approved'
 where id='00000000-0000-0000-0000-000000000101';
update public.team_skills_registrations set status='approved'
 where id='00000000-0000-0000-0000-000000000101';
update public.team_skills_registrations set status='rejected'
 where id='00000000-0000-0000-0000-000000000102';
update public.team_skills_registrations set status='waitlist'
 where id='00000000-0000-0000-0000-000000000103';
do $assert$
declare total integer;uniq integer;correct integer;
begin
 select count(*), count(distinct n.metadata->>'registration_id'),
   count(*) filter (where n.user_id=r.captain_id and
       n.metadata->>'status'=r.status and
       n.metadata->>'cup_id'=r.cup_id::text)
 into total,uniq,correct
 from public.notifications n
 join public.team_skills_registrations r on r.id::text=n.metadata->>'registration_id'
 where n.metadata->>'event'='registration_review'
   and n.metadata->>'source'='team_skills_cup';
 if total<>3 or uniq<>3 or correct<>3 then
  raise exception 'BAD_TEAM_STATUS_NOTIFICATIONS: total %, unique %, scoped %',total,uniq,correct;
 end if;
end $assert$;
