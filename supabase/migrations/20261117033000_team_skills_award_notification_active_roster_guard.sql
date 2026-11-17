-- Team Skills recipient privacy: award announcements go only to the approved
-- winning team's active competition roster and captain. Inactive/withdrawn
-- former players and other cup/team members must not be notified.
-- No payment, original award, or historic notification row is modified.
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
     and r.status='approved'
     and roster.cup_id=new.cup_id and roster.active=true
   union
   select r.captain_id from public.team_skills_registrations r
   where r.cup_id=new.cup_id and r.team_id=new.team_id
     and r.status='approved'
 ) member;
 return new;
end $$;
revoke all on function vsp_skills_private.notify_award()
 from public,anon,authenticated;
