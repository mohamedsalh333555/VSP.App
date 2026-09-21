-- PUBLIC grants inherit to anon. Revoke both PUBLIC and anon explicitly.
revoke execute on function public.create_booking_atomic(
  text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,
  text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric
) from public, anon;

revoke execute on function public.create_booking_atomic(
  text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,
  text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text
) from public, anon;

grant execute on function public.create_booking_atomic(
  text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,
  text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric
) to authenticated, service_role;

grant execute on function public.create_booking_atomic(
  text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,
  text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text
) to authenticated, service_role;
