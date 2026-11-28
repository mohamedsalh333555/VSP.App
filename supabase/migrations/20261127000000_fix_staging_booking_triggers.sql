-- Fix root causes in booking_public_feed sync trigger and open_join gen_random_bytes
-- 1) Replace excluded.opponent_team_logo with excluded.opponent_team_logo_url
-- 2) Ensure pgcrypto extensions schema is in search_path for gen_random_bytes

CREATE OR REPLACE FUNCTION public.sync_booking_public_feed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.booking_public_feed WHERE id = OLD.id;
    RETURN OLD;
  END IF;

  IF NEW.is_private = false AND NEW.status IN ('pending', 'confirmed', 'completed') THEN
    INSERT INTO public.booking_public_feed (
      id, stadium_id, stadium_name, stadium_image_url, start_time, end_time,
      operational_date, booking_type, player_team_id, player_team_name,
      player_team_logo_url, host_name, host_avatar_url, opponent_team_id,
      opponent_team_name, opponent_team_logo_url, is_private, rent_ball,
      total_price, currency, status, match_result_status, home_score,
      away_score, final_outcome, current_players, players_per_team,
      total_field_capacity, matchup_mode, matchup_closed_at,
      created_at, updated_at
    )
    VALUES (
      NEW.id, NEW.stadium_id, NEW.stadium_name, NEW.stadium_image_url,
      NEW.start_time, NEW.end_time, NEW.operational_date, NEW.booking_type,
      NEW.player_team_id, NEW.player_team_name, NEW.player_team_logo_url,
      NEW.host_name, NEW.host_avatar_url, NEW.opponent_team_id,
      NEW.opponent_team_name, NEW.opponent_team_logo_url, NEW.is_private,
      NEW.rent_ball, NEW.total_price, NEW.currency, NEW.status,
      NEW.match_result_status, NEW.home_score, NEW.away_score,
      NEW.final_outcome, NEW.current_players, NEW.max_players,
      NEW.total_field_capacity, NEW.matchup_mode, NEW.matchup_closed_at,
      NEW.created_at, NEW.updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
      stadium_id = EXCLUDED.stadium_id,
      stadium_name = EXCLUDED.stadium_name,
      stadium_image_url = EXCLUDED.stadium_image_url,
      start_time = EXCLUDED.start_time,
      end_time = EXCLUDED.end_time,
      operational_date = EXCLUDED.operational_date,
      booking_type = EXCLUDED.booking_type,
      player_team_id = EXCLUDED.player_team_id,
      player_team_name = EXCLUDED.player_team_name,
      player_team_logo_url = EXCLUDED.player_team_logo_url,
      host_name = EXCLUDED.host_name,
      host_avatar_url = EXCLUDED.host_avatar_url,
      opponent_team_id = EXCLUDED.opponent_team_id,
      opponent_team_name = EXCLUDED.opponent_team_name,
      opponent_team_logo_url = EXCLUDED.opponent_team_logo_url,
      is_private = EXCLUDED.is_private,
      rent_ball = EXCLUDED.rent_ball,
      total_price = EXCLUDED.total_price,
      currency = EXCLUDED.currency,
      status = EXCLUDED.status,
      match_result_status = EXCLUDED.match_result_status,
      home_score = EXCLUDED.home_score,
      away_score = EXCLUDED.away_score,
      final_outcome = EXCLUDED.final_outcome,
      current_players = EXCLUDED.current_players,
      players_per_team = EXCLUDED.players_per_team,
      total_field_capacity = EXCLUDED.total_field_capacity,
      matchup_mode = EXCLUDED.matchup_mode,
      matchup_closed_at = EXCLUDED.matchup_closed_at,
      updated_at = EXCLUDED.updated_at;
  ELSE
    DELETE FROM public.booking_public_feed WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;
