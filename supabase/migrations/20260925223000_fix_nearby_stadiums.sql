create or replace function public.get_nearby_stadiums(
  user_lat numeric,
  user_lng numeric,
  max_limit integer default 10
)
returns setof public.stadiums
language sql
stable
security invoker
set search_path = public
as $$
  select s.*
  from public.stadiums s
  where coalesce(s.is_verified, false) = true
    and coalesce(s.is_blocked, false) = false
    and coalesce(s.is_deleted_by_owner, false) = false
    and s.lat is not null
    and s.lng is not null
  order by ((s.lat - user_lat) * (s.lat - user_lat)
          + (s.lng - user_lng) * (s.lng - user_lng)) asc
  limit greatest(1, least(coalesce(max_limit, 10), 100));
$$;

revoke execute on function public.get_nearby_stadiums(numeric, numeric, integer) from public, anon;
grant execute on function public.get_nearby_stadiums(numeric, numeric, integer) to authenticated;
