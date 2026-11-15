-- Candidate for staging verification. Preserves the installed function body and
-- permissions; refuse any unreviewed function definition instead of replacing
-- unrelated authorization, idempotency or booking safeguards.
DO $migration$
DECLARE
  v_signature regprocedure := 'public.create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer)'::regprocedure;
  v_definition text;
  v_marker text := '  v_final_total_price:=v_calculated_price;';
  v_check text := $check$  IF p_total_price IS NULL OR p_total_price::text IN ('NaN', 'Infinity', '-Infinity')
     OR abs(p_total_price-v_calculated_price)>0.01 THEN
    RETURN jsonb_build_object(
      'success',false,
      'code','PRICE_MISMATCH',
      'expected_total_price',v_calculated_price,
      'message','تغير سعر الملعب قبل تأكيد الحجز. راجع السعر وحاول مرة أخرى.'
    );
  END IF;

$check$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF md5(v_definition) NOT IN (
    '2321f043d057cad50edfbf0d95040022', -- inspected staging, 2026-11-15
    '17063e8e0d641200bcc0a9b22fa879f9'  -- inspected production; not applied there
  ) THEN
    RAISE EXCEPTION 'BOOKING_PRICE_FUNCTION_DRIFT: review the installed function before changing it';
  END IF;
  IF length(v_definition)-length(replace(v_definition,v_marker,'')) <> length(v_marker) THEN
    RAISE EXCEPTION 'BOOKING_PRICE_MARKER_DRIFT';
  END IF;
  EXECUTE replace(v_definition,v_marker,v_check||v_marker)||';';
  IF position('PRICE_MISMATCH' IN pg_get_functiondef(v_signature)) = 0 THEN
    RAISE EXCEPTION 'BOOKING_PRICE_GUARD_NOT_INSTALLED';
  END IF;
END;
$migration$;
