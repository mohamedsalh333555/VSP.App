-- Captain-only, approved-only stage results for Team Skills Cup.
-- Do not notify players about judge drafts, rejected scores, unpublished or
-- cancelled cups. This is a transactional in-app receipt, not an FCM push.
create or replace function vsp_skills_private.notify_approved_phase_score()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_captain_id uuid;
  v_team_id uuid;
begin
  if new.status<>'approved'
      or new.approved_by is null or new.approved_at is null then
    return new;
  end if;
  if tg_op='UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;
  select r.captain_id,r.team_id into v_captain_id,v_team_id
    from public.team_skills_registrations r
    join public.team_skills_cups c on c.id=r.cup_id
    where r.id=new.registration_id and r.cup_id=new.cup_id
      and r.status='approved' and c.status='live';
  if v_captain_id is null then return new; end if;
  insert into public.notifications(
    user_id,title,body,message,type,metadata
  )
  select v_captain_id,'تم اعتماد نتيجة مرحلة في بطولة مهارات الفرق',
    'تم اعتماد نتيجة المرحلة ' || new.stage_no::text ||
      ' لفريقك. النقاط المعتمدة: ' || new.computed_points::text || '.',
    'تم اعتماد نتيجة المرحلة ' || new.stage_no::text ||
      ' لفريقك. النقاط المعتمدة: ' || new.computed_points::text || '.',
    'info',
    jsonb_build_object(
      'source','team_skills_cup','event','phase_score_approved',
      'cup_id',new.cup_id,'team_id',v_team_id,
      'registration_id',new.registration_id,'score_id',new.id,
      'stage_no',new.stage_no
    )
  where not exists(
    select 1 from public.notifications n
    where n.user_id=v_captain_id
      and n.metadata->>'source'='team_skills_cup'
      and n.metadata->>'event'='phase_score_approved'
      and n.metadata->>'score_id'=new.id::text
  );
  return new;
end $$;
revoke all on function vsp_skills_private.notify_approved_phase_score()
 from public,anon,authenticated;
drop trigger if exists team_skills_phase_approved_notify
 on public.team_skills_scores;
create trigger team_skills_phase_approved_notify
after insert or update of status on public.team_skills_scores
for each row execute function vsp_skills_private.notify_approved_phase_score();
