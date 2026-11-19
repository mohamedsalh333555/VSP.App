-- Disposable isolated SQL test using the current award notification trigger.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create schema vsp_skills_private;
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,team_id uuid not null,
 captain_id uuid not null,status text not null);
create table public.team_skills_roster(
 registration_id uuid,cup_id uuid,player_id uuid,active boolean not null);
create table public.team_skills_awards(
 cup_id uuid,award_type text,team_id uuid);
create table public.notifications(
 user_id uuid,title text,body text,message text,type text,metadata jsonb);
-- ACTUAL_TEAM_SKILLS_AWARD_NOTICE_MIGRATION
create trigger team_skills_award_notify
after insert on public.team_skills_awards
for each row execute function vsp_skills_private.notify_award();

insert into public.team_skills_registrations(id,cup_id,team_id,captain_id,status) values
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000009001','approved'),
 ('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000009008','approved'),
 ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000009010','approved'),
 ('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000009012','withdrawn');
insert into public.team_skills_roster(registration_id,cup_id,player_id,active) values
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000009001',true),
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000009002',true),
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000009003',true),
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000009006',false),
 ('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000009009',true),
 ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000009011',true),
 ('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000009013',true);
insert into public.team_skills_awards(cup_id,award_type,team_id)
values('00000000-0000-0000-0000-000000000001','team_champion',
       '00000000-0000-0000-0000-000000000201');
do $verify$
begin
 if (select count(*) from public.notifications)<>3
 or (select count(distinct user_id) from public.notifications)<>3
 or (select count(*) from public.notifications
     where user_id in (
       '00000000-0000-0000-0000-000000009001',
       '00000000-0000-0000-0000-000000009002',
       '00000000-0000-0000-0000-000000009003')
      and metadata->>'source'='team_skills_cup'
      and metadata->>'cup_id'='00000000-0000-0000-0000-000000000001'
      and metadata->>'team_id'='00000000-0000-0000-0000-000000000201'
      and metadata->>'award'='team_champion')<>3
 then raise exception 'AWARD_WRONG_RECIPIENTS_OR_METADATA';end if;
 if exists(select 1 from public.notifications where user_id in (
       '00000000-0000-0000-0000-000000009006',
       '00000000-0000-0000-0000-000000009008',
       '00000000-0000-0000-0000-000000009009',
       '00000000-0000-0000-0000-000000009010',
       '00000000-0000-0000-0000-000000009011',
       '00000000-0000-0000-0000-000000009012',
       '00000000-0000-0000-0000-000000009013'))
 then raise exception 'INACTIVE_OR_OTHER_TEAM_AWARD_NOTIFICATION_LEAK';end if;
end $verify$;
