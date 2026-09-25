-- Team sensitive-field role coherence -- 2026-09-26
create or replace function public.protect_team_sensitive_fields()
returns trigger language plpgsql security definer set search_path=public,pg_temp
as $function$
declare v_caller_role text;
begin
  if current_user in ('postgres','service_role') then return new; end if;
  select role into v_caller_role from public.users where id=auth.uid();
  if v_caller_role in ('admin','co_founder','cofounder','super_admin') then return new; end if;

  if new.is_verified is distinct from old.is_verified and new.is_verified=true then
    raise exception 'Security Alert: Team verification requires admin approval.';
  end if;
  if new.is_blocked is distinct from old.is_blocked and new.is_blocked=false then
    raise exception 'Security Alert: Team unblocking requires admin approval.';
  end if;

  new.points:=old.points;
  new.wins:=old.wins;
  new.draws:=old.draws;
  new.losses:=old.losses;
  new.matches_played:=old.matches_played;
  new.current_winning_streak:=old.current_winning_streak;
  new.championships_won:=old.championships_won;
  new.elo_rating:=old.elo_rating;
  new.attendance_score:=old.attendance_score;
  new.verified_badge:=old.verified_badge;
  new.is_official:=old.is_official;
  new.has_1v1_champion:=old.has_1v1_champion;
  new.beaten_opponents:=old.beaten_opponents;
  new.played_opponents:=old.played_opponents;
  new.unlocked_badges:=old.unlocked_badges;
  new.last_reset_year:=old.last_reset_year;
  return new;
end;
$function$;
