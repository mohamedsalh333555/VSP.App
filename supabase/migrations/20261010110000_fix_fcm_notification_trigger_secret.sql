-- Fix FCM database-trigger authentication.
-- The trigger must use the existing high-entropy secret stored in
-- internal_function_secrets; never hardcode a placeholder token in SQL.

CREATE OR REPLACE FUNCTION public.handle_new_notification_fcm()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions, pg_temp
AS $$
DECLARE
  v_url text := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/fcm_push';
  v_secret text;
BEGIN
  SELECT s.secret
    INTO v_secret
  FROM public.internal_function_secrets AS s
  WHERE s.name = 'fcm_push'
  LIMIT 1;

  IF v_secret IS NULL OR length(v_secret) < 32 THEN
    RAISE WARNING 'FCM push trigger skipped: internal secret is missing or too short';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body := jsonb_build_object('record', row_to_json(NEW))
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'FCM push trigger exception (safe-bypass): %', SQLERRM;
  RETURN NEW;
END;
$$;
