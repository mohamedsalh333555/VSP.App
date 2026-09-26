-- Public booking privacy boundary
create table if not exists public.booking_public_feed (
  id uuid primary key,
  stadium_id uuid,
  stadium_name text,
  stadium_image_url text,
  start_time timestamptz not null,
  end_time timestamptz not null,
  operational_date date,
  booking_type text,
  player_team_id uuid,
  player_team_name text,
  player_team_logo_url text,
  host_name text,
  host_avatar_url text,
  opponent_team_id uuid,
  opponent_team_name text,
  opponent_team_logo_url text,
  is_private boolean not null default false,
  rent_ball boolean not null default false,
  total_price numeric not null default 0,
  currency text not null default 'EGP',
  status text not null,
  match_result_status text default 'noResult',
  home_score integer,
  away_score integer,
  final_outcome text,
  current_players integer not null default 1,
  players_per_team integer not null default 5,
  total_field_capacity integer not null default 10,
  matchup_mode text,
  matchup_closed_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

alter table public.booking_public_feed enable row level security;
revoke all on public.booking_public_feed from anon, authenticated;
grant select on public.booking_public_feed to authenticated;
drop policy if exists booking_public_feed_select on public.booking_public_feed;
create policy booking_public_feed_select on public.booking_public_feed for select to authenticated using (true);

create or replace function public.sync_booking_public_feed()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if tg_op='DELETE' then delete from public.booking_public_feed where id=old.id; return old; end if;
  if new.is_private=false and new.status in ('pending','confirmed','completed') then
    insert into public.booking_public_feed (
      id,stadium_id,stadium_name,stadium_image_url,start_time,end_time,operational_date,booking_type,
      player_team_id,player_team_name,player_team_logo_url,host_name,host_avatar_url,opponent_team_id,
      opponent_team_name,opponent_team_logo_url,is_private,rent_ball,total_price,currency,status,
      match_result_status,home_score,away_score,final_outcome,current_players,players_per_team,
      total_field_capacity,matchup_mode,matchup_closed_at,created_at,updated_at)
    values (
      new.id,new.stadium_id,new.stadium_name,new.stadium_image_url,new.start_time,new.end_time,new.operational_date,new.booking_type,
      new.player_team_id,new.player_team_name,new.player_team_logo_url,new.host_name,new.host_avatar_url,new.opponent_team_id,
      new.opponent_team_name,new.opponent_team_logo_url,new.is_private,new.rent_ball,new.total_price,new.currency,new.status,
      new.match_result_status,new.home_score,new.away_score,new.final_outcome,new.current_players,new.max_players,
      new.total_field_capacity,new.matchup_mode,new.matchup_closed_at,new.created_at,new.updated_at)
    on conflict(id) do update set
      stadium_id=excluded.stadium_id,stadium_name=excluded.stadium_name,stadium_image_url=excluded.stadium_image_url,
      start_time=excluded.start_time,end_time=excluded.end_time,operational_date=excluded.operational_date,booking_type=excluded.booking_type,
      player_team_id=excluded.player_team_id,player_team_name=excluded.player_team_name,player_team_logo_url=excluded.player_team_logo_url,
      host_name=excluded.host_name,host_avatar_url=excluded.host_avatar_url,opponent_team_id=excluded.opponent_team_id,
      opponent_team_name=excluded.opponent_team_name,opponent_team_logo_url=excluded.opponent_team_logo_url,is_private=excluded.is_private,
      rent_ball=excluded.rent_ball,total_price=excluded.total_price,currency=excluded.currency,status=excluded.status,
      match_result_status=excluded.match_result_status,home_score=excluded.home_score,away_score=excluded.away_score,
      final_outcome=excluded.final_outcome,current_players=excluded.current_players,players_per_team=excluded.players_per_team,
      total_field_capacity=excluded.total_field_capacity,matchup_mode=excluded.matchup_mode,matchup_closed_at=excluded.matchup_closed_at,
      created_at=excluded.created_at,updated_at=excluded.updated_at;
  else delete from public.booking_public_feed where id=new.id;
  end if;
  return new;
end; $$;

drop trigger if exists trg_sync_booking_public_feed on public.bookings;
create trigger trg_sync_booking_public_feed after insert or update or delete on public.bookings
for each row execute function public.sync_booking_public_feed();

revoke all on function public.sync_booking_public_feed() from public,anon,authenticated;
grant execute on function public.sync_booking_public_feed() to service_role;

create or replace function public.get_stadium_booking_slots(p_stadium_id uuid,p_start_time timestamptz,p_end_time timestamptz)
returns table(id uuid,stadium_id uuid,stadium_name text,stadium_image_url text,start_time timestamptz,end_time timestamptz,status text,booking_type text,is_private boolean,current_players integer,total_field_capacity integer,created_at timestamptz,updated_at timestamptz)
language sql stable security invoker set search_path=public as $$
 select b.id,b.stadium_id,b.stadium_name,b.stadium_image_url,b.start_time,b.end_time,b.status,b.booking_type,b.is_private,
        b.current_players,b.total_field_capacity,b.created_at,b.updated_at
 from public.bookings b
 where b.stadium_id=p_stadium_id and b.start_time>=p_start_time and b.start_time<p_end_time
   and b.status<>'cancelled' and (b.status<>'pending' or b.created_at>=now()-interval '8 minutes')
 order by b.start_time $$;
revoke all on function public.get_stadium_booking_slots(uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.get_stadium_booking_slots(uuid,timestamptz,timestamptz) to authenticated;

drop policy if exists bookings_select_unified on public.bookings;
create policy bookings_select_private_scope on public.bookings for select to authenticated using (
 auth.uid()=user_id or auth.uid()=owner_id or auth.uid()=created_by_user_id
 or auth.uid()=any(coalesce(joined_user_ids,array[]::uuid[])) or is_admin_or_cofounder(auth.uid())
);

drop policy if exists transactions_select_policy on public.transactions;
drop policy if exists transactions_owner_or_admin_select on public.transactions;
create policy transactions_select_owner_or_admin on public.transactions for select to authenticated using (
 user_id=auth.uid() or exists(select 1 from bookings b where b.id=transactions.booking_id and b.owner_id=auth.uid())
 or is_admin_or_cofounder(auth.uid())
);

drop policy if exists payout_settlements_select_policy on public.payout_settlements;
drop policy if exists payout_settlements_owner_or_admin_select on public.payout_settlements;
create policy payout_settlements_select_owner_or_admin on public.payout_settlements for select to authenticated using (
 owner_id=auth.uid() or is_admin_or_cofounder(auth.uid())
);
