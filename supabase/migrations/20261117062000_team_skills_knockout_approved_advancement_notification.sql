-- Notify the winning captain ONLY after an approved first/second-side
-- knockout result has actually populated the next-round slot.
-- Initial bracket seeding, placeholders, cancellations and unapproved
-- scores are not qualifications. Transactional in-app only, not FCM.
create or replace function vsp_skills_private.notify_knockout_advancement()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_cup_status text;
  v_previous_match uuid;
  v_registration_id uuid;
  v_captain_id uuid;
  v_team_id uuid;
  v_side integer;
begin
  if new.round_no<=1 or new.status<>'scheduled' then return new;end if;
  select c.status into v_cup_status from public.team_skills_cups c
    where c.id=new.cup_id;
  if v_cup_status<>'live' then return new;end if;

  for v_side in 1..2 loop
    if v_side=1 then
      v_registration_id:=new.first_registration_id;
      if v_registration_id is null or
         v_registration_id is not distinct from old.first_registration_id
      then continue;end if;
    else
      v_registration_id:=new.second_registration_id;
      if v_registration_id is null or
         v_registration_id is not distinct from old.second_registration_id
      then continue;end if;
    end if;
    -- A team seeded straight into a future slot is not yet the winner of
    -- an approved knockout match: require the exact earlier result.
    select m.id into v_previous_match
    from public.team_skills_knockout m
    where m.cup_id=new.cup_id and m.round_no=new.round_no-1
      and m.match_no=2*new.match_no-2+v_side
      and m.status='approved'
      and m.winner_registration_id=v_registration_id;
    if v_previous_match is null then continue;end if;
    select r.captain_id,r.team_id into v_captain_id,v_team_id
      from public.team_skills_registrations r
      where r.id=v_registration_id and r.cup_id=new.cup_id
        and r.status='approved';
    if v_captain_id is null then continue;end if;

    insert into public.notifications(user_id,title,body,message,type,metadata)
    select v_captain_id,'تأهل ممثل فريقك في ختام 1 ضد 1',
      'بعد اعتماد نتيجة الفوز، تأهل ممثل فريقك إلى الدور التالي في ختام 1 ضد 1.',
      'بعد اعتماد نتيجة الفوز، تأهل ممثل فريقك إلى الدور التالي في ختام 1 ضد 1.',
      'info',
      jsonb_build_object(
        'source','team_skills_cup','event','knockout_advancement',
        'cup_id',new.cup_id,'team_id',v_team_id,
        'registration_id',v_registration_id,
        'match_id',v_previous_match,'next_round',new.round_no
      )
    where not exists(
      select 1 from public.notifications n
      where n.user_id=v_captain_id
        and n.metadata->>'source'='team_skills_cup'
        and n.metadata->>'event'='knockout_advancement'
        and n.metadata->>'match_id'=v_previous_match::text
    );
  end loop;
  return new;
end $$;
revoke all on function vsp_skills_private.notify_knockout_advancement()
 from public,anon,authenticated;
drop trigger if exists team_skills_knockout_advancement_notify
 on public.team_skills_knockout;
create trigger team_skills_knockout_advancement_notify
after update of first_registration_id,second_registration_id
on public.team_skills_knockout
for each row execute function vsp_skills_private.notify_knockout_advancement();
