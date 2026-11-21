-- Preserve the existing deletion safeguards while using the current venue schema.
DO $repair$
DECLARE
  routine regprocedure := 'public.delete_user_permanently(uuid)'::regprocedure;
  original text;
  body text;
  obsolete constant text := 'from public.stadiums where owner_id=p_user_id and is_active=true';
  corrected constant text := 'from public.stadiums s where s.owner_id=p_user_id and (
      s.is_deleted_by_owner is not true
      or exists (select 1 from public.championships c where c.stadium_id=s.id)
      or exists (select 1 from public.bookings b where b.stadium_id=s.id and b.status in (''pending'',''confirmed'') and b.end_time>now()))';
BEGIN
  SELECT prosrc, pg_get_functiondef(oid) INTO body, original FROM pg_proc WHERE oid=routine;
  IF strpos(body, corrected)>0 THEN RETURN; END IF;
  IF length(body)-length(replace(body,obsolete,'')) <> length(obsolete) THEN
    RAISE EXCEPTION 'Unrecognized owner deletion venue check';
  END IF;
  EXECUTE replace(original,obsolete,corrected);
END;
$repair$;
