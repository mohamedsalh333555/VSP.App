-- Transactional captain-only receipt for the *initial* application.
-- Review decisions are already notified by the AFTER UPDATE status trigger.
-- An initial WAITLIST entry never fires UPDATE, so the captain needs this
-- separate receipt. No marketing pushes or financial settlement are implied.
create or replace function vsp_skills_private.notify_team_skills_registration_receipt()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_title text; v_body text;
begin
 if new.status not in ('pending','waitlist') then return new; end if;
 if new.status='waitlist' then
   v_title:='فريقك في قائمة انتظار بطولة مهارات الفرق';
   v_body:='تم استلام طلبك على قائمة الانتظار. ستصلك حالة جديدة إذا توفر مكان وتمت المراجعة.';
 else
   v_title:='تم استلام طلب مشاركة فريقك';
   v_body:='تم تسجيل طلب فريقك في بطولة مهارات الفرق. الطلب قيد مراجعة الإدارة ولم يُعتمد بعد.';
 end if;
 insert into public.notifications(user_id,title,body,message,type,metadata)
 values(new.captain_id,v_title,v_body,v_body,'info',
   jsonb_build_object(
     'source','team_skills_cup',
     'event','registration_submitted',
     'cup_id',new.cup_id,
     'team_id',new.team_id,
     'registration_id',new.id,
     'status',new.status
   ));
 return new;
end $$;

revoke all on function vsp_skills_private.notify_team_skills_registration_receipt()
 from public,anon,authenticated;
drop trigger if exists team_skills_registration_submission_notify
 on public.team_skills_registrations;
create trigger team_skills_registration_submission_notify
after insert on public.team_skills_registrations
for each row execute function vsp_skills_private.notify_team_skills_registration_receipt();
