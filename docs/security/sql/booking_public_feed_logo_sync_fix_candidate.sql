-- CODE CANDIDATE ONLY — DO NOT APPLY TO HOSTED DATABASE AUTOMATICALLY.
-- Staging read-only inspection: trg_sync_booking_public_feed calls this function
-- on every booking INSERT/UPDATE/DELETE, and its UPDATE branch incorrectly
-- references excluded.opponent_team_logo (not an inserted column).
-- The column is opponent_team_logo_url. The function below preserves the
-- currently installed body and changes only the one invalid reference.
-- Requires transaction-scoped staging regression, access/owner permissions
-- review, financial snapshots and rollback approval before deployment.

CREATE OR REPLACE FUNCTION public.sync_booking_public_feed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE' then
    delete from public.booking_public_feed where id=old.id;
    return old;
  end if;

  if new.is_private=false
     and new.booking_type<>'open_join'
     and new.status in ('pending','confirmed','completed') then
    insert into public.booking_public_feed (
      id,stadium_id,stadium_name,stadium_image_url,start_time,end_time,operational_date,
      booking_type,player_team_id,player_team_name,player_team_logo_url,host_name,host_avatar_url,
      opponent_team_id,opponent_team_name,opponent_team_logo_url,is_private,rent_ball,total_price,currency,
      status,match_result_status,home_score,away_score,final_outcome,current_players,players_per_team,
      total_field_capacity,matchup_mode,matchup_closed_at,created_at,updated_at
    ) values (
      new.id,new.stadium_id,new.stadium_name,new.stadium_image_url,new.start_time,new.end_time,new.operational_date,
      new.booking_type,new.player_team_id,new.player_team_name,new.player_team_logo_url,new.host_name,new.host_avatar_url,
      new.opponent_team_id,new.opponent_team_name,new.opponent_team_logo_url,new.is_private,new.rent_ball,new.total_price,new.currency,
      new.status,new.match_result_status,new.home_score,new.away_score,new.final_outcome,new.current_players,new.max_players,
      new.total_field_capacity,new.matchup_mode,new.matchup_closed_at,new.created_at,new.updated_at
    )
    on conflict(id) do update set
      stadium_id=excluded.stadium_id,stadium_name=excluded.stadium_name,stadium_image_url=excluded.stadium_image_url,
      start_time=excluded.start_time,end_time=excluded.end_time,operational_date=excluded.operational_date,
      booking_type=excluded.booking_type,player_team_id=excluded.player_team_id,player_team_name=excluded.player_team_name,
      player_team_logo_url=excluded.player_team_logo_url,host_name=excluded.host_name,host_avatar_url=excluded.host_avatar_url,
      opponent_team_id=excluded.opponent_team_id,opponent_team_name=excluded.opponent_team_name,
      opponent_team_logo_url=excluded.opponent_team_logo_url,is_private=excluded.is_private,rent_ball=excluded.rent_ball,
      total_price=excluded.total_price,currency=excluded.currency,status=excluded.status,
      match_result_status=excluded.match_result_status,home_score=excluded.home_score,away_score=excluded.away_score,
      final_outcome=excluded.final_outcome,current_players=excluded.current_players,players_per_team=excluded.players_per_team,
      total_field_capacity=excluded.total_field_capacity,matchup_mode=excluded.matchup_mode,
      matchup_closed_at=excluded.matchup_closed_at,created_at=excluded.created_at,updated_at=excluded.updated_at;
  else
    delete from public.booking_public_feed where id=new.id;
  end if;
  return new;
end;
$function$;
