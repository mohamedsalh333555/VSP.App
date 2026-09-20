-- Tighten anonymous access to booking RPC overloads.
-- Both functions already enforce authenticated caller identity internally.
revoke execute on function public.create_booking_atomic(
  text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,
  text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric
) from anon;

revoke execute on function public.create_booking_atomic(
  text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,
  text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text
) from anon;
