-- Championship financial/lifecycle field hardening -- 2026-09-26
create or replace function public.protect_championship_sensitive_fields()
returns trigger language plpgsql security definer set search_path=public,pg_temp
as $function$
declare v_caller_role text; v_has_participants boolean:=false;
begin
  if current_user in ('postgres','service_role') then return new; end if;
  select role into v_caller_role from public.users where id=auth.uid();
  if v_caller_role in ('admin','co_founder','super_admin','cofounder') then return new; end if;

  if tg_op='INSERT' then
    if coalesce(new.is_approved,false)=true or coalesce(new.creation_fee_paid,false)=true then
      raise exception 'Security Alert: Approval and creation-fee state are server-authoritative.';
    end if;
    return new;
  end if;

  select cardinality(coalesce(old.paid_teams,array[]::text[]))>0
      or cardinality(coalesce(old.joined_teams,array[]::text[]))>0
      or old.registration_locked_at is not null
  into v_has_participants;

  if new.is_approved is distinct from old.is_approved
     or new.champion_team_id is distinct from old.champion_team_id
     or new.winner_team_id is distinct from old.winner_team_id
     or new.champion_user_id is distinct from old.champion_user_id
     or new.paid_teams is distinct from old.paid_teams
     or new.joined_teams is distinct from old.joined_teams
     or new.prize_pool is distinct from old.prize_pool
     or new.creation_fee_paid is distinct from old.creation_fee_paid
     or new.creation_payment_id is distinct from old.creation_payment_id
     or new.prize_delivered is distinct from old.prize_delivered
     or new.prize_delivered_at is distinct from old.prize_delivered_at
     or new.prize_delivered_by is distinct from old.prize_delivered_by
     or new.prize_delivery_notes is distinct from old.prize_delivery_notes
     or new.registration_locked_at is distinct from old.registration_locked_at then
    raise exception 'Security Alert: Championship financial, roster, approval and result fields are server-authoritative.';
  end if;

  if v_has_participants and (
     new.entry_fee is distinct from old.entry_fee
     or new.grand_prize is distinct from old.grand_prize
     or new.max_teams is distinct from old.max_teams
     or new.min_players_per_team is distinct from old.min_players_per_team
     or new.max_players_per_team is distinct from old.max_players_per_team
  ) then
    raise exception 'Security Alert: Competition financial/capacity settings cannot change after registration has started.';
  end if;

  return new;
end;
$function$;
drop trigger if exists trg_protect_championship_sensitive_fields on public.championships;
create trigger trg_protect_championship_sensitive_fields
before insert or update on public.championships for each row
execute function public.protect_championship_sensitive_fields();
