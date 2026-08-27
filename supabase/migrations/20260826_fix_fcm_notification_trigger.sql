-- Fix: 20260826_fix_fcm_notification_trigger.sql
-- Update trigger function to correctly invoke fcm_push Edge Function asynchronously

CREATE OR REPLACE FUNCTION public.handle_new_notification_fcm()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_url text;
BEGIN
  v_url := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/fcm_push';
  
  -- Send async HTTP POST via pg_net with internal authorization
  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer internal_db_trigger'
    ),
    body := jsonb_build_object(
      'record', row_to_json(NEW)
    )
  );
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Non-blocking fail-safe: Database insertion NEVER fails if push network fails
  RAISE WARNING 'FCM push trigger exception (safe-bypass): %', SQLERRM;
  RETURN NEW;
END;
$$;
