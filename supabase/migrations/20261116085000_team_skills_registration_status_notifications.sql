-- Transactional, captain-only notifications for Team Skills registration
-- decisions. No marketing consent assumptions, FCM side effects, or new billing.
-- The existing notifications feed is the delivery mechanism.
create or replace function vsp_skills_private.notify_team_skills_registration_status()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_title text;
  v_body text;
begin
  if old.status is not distinct from new.status
     or new.status not in ('approved','rejected','waitlist') then
    return new;
  end if;

  v_title:=case new.status
    when 'approved' then 'تم قبول فريقك في بطولة مهارات الفرق'
    when 'rejected' then 'تحديث طلب المشاركة في بطولة مهارات الفرق'
    else 'فريقك على قائمة انتظار بطولة مهارات الفرق'
  end;
  v_body:=case new.status
    when 'approved' then 'تم اعتماد مشاركة فريقك. راجع تفاصيل البطولة ومواعيد الحضور.'
    when 'rejected' then 'لم تتم الموافقة على طلب فريقك. يمكنك مراجعة حالة الطلب مع إدارة البطولة.'
    else 'طلب فريقك على قائمة الانتظار. سنظهر أي تحديث في حالة المشاركة.'
  end;

  insert into public.notifications(user_id,title,body,message,type,metadata)
  values(new.captain_id,v_title,v_body,v_body,
    case when new.status='approved' then 'tournament_approval' else 'info' end,
    jsonb_build_object(
      'source','team_skills_cup',
      'event','registration_review',
      'cup_id',new.cup_id,
      'team_id',new.team_id,
      'registration_id',new.id,
      'status',new.status
    )
  );
  return new;
end $$;

revoke all on function vsp_skills_private.notify_team_skills_registration_status()
  from public,anon,authenticated;
drop trigger if exists team_skills_registration_review_notify
  on public.team_skills_registrations;
create trigger team_skills_registration_review_notify
after update of status on public.team_skills_registrations
for each row
when (old.status is distinct from new.status)
execute function vsp_skills_private.notify_team_skills_registration_status();
