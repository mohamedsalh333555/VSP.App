-- Award history is a view of approved champions (not legacy teams.points/Elo).
create or replace view public.team_skills_team_history with (security_invoker=true) as
select a.team_id, c.id as cup_id, c.name as cup_name, c.governorate,
 a.award_type, a.player_id, a.announced_at
from public.team_skills_awards a
join public.team_skills_cups c on c.id=a.cup_id
where c.status='completed';
revoke all on public.team_skills_team_history from public,anon;
grant select on public.team_skills_team_history to authenticated;

create or replace view public.team_skills_player_history with (security_invoker=true) as
select a.player_id, a.team_id,c.id as cup_id,c.name as cup_name,
 a.award_type,a.announced_at
from public.team_skills_awards a
join public.team_skills_cups c on c.id=a.cup_id
where c.status='completed' and a.player_id is not null;
revoke all on public.team_skills_player_history from public,anon;
grant select on public.team_skills_player_history to authenticated;

-- An immutable, one-time award row is the source for in-app notifications.
-- No legacy championship, subscription, payment or booking columns are touched.
create or replace function vsp_skills_private.notify_award()
returns trigger language plpgsql security definer set search_path='' as $$
declare title_text text; body_text text;
begin
 title_text:=case new.award_type
   when 'team_champion' then 'بطل مهارات الفرق — VSP'
   when 'one_v_one_champion' then 'بطل ختام 1 ضد 1 — VSP'
   else 'أفضل حارس — VSP' end;
 body_text:=case new.award_type
   when 'team_champion' then 'فاز فريقك بلقب بطولة مهارات الفرق!'
   when 'one_v_one_champion' then 'حصل ممثل فريقك على لقب ختام 1 ضد 1!'
   else 'أحرز حارس فريقك جائزة أفضل حارس!' end;
 insert into public.notifications(user_id,title,body,message,type,metadata)
 select member.user_id,title_text,body_text,body_text,'achievement',
   jsonb_build_object('source','team_skills_cup','cup_id',new.cup_id,
    'team_id',new.team_id,'award',new.award_type)
 from (
   select distinct roster.player_id as user_id
   from public.team_skills_roster roster
   join public.team_skills_registrations r on r.id=roster.registration_id
   where r.cup_id=new.cup_id and r.team_id=new.team_id
   union
   select r.captain_id from public.team_skills_registrations r
   where r.cup_id=new.cup_id and r.team_id=new.team_id
 ) member;
 return new;
end $$;
drop trigger if exists team_skills_award_notify on public.team_skills_awards;
create trigger team_skills_award_notify
after insert on public.team_skills_awards
for each row execute function vsp_skills_private.notify_award();
revoke all on function vsp_skills_private.notify_award() from public,anon;
