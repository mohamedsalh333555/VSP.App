-- 1. Add P2P receivables columns to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS p2p_instapay TEXT,
ADD COLUMN IF NOT EXISTS p2p_vodafone TEXT,
ADD COLUMN IF NOT EXISTS p2p_bank TEXT;

-- 2. Enforce unique review constraint per user per stadium
ALTER TABLE public.reviews
DROP CONSTRAINT IF EXISTS unique_user_stadium_review;

ALTER TABLE public.reviews
ADD CONSTRAINT unique_user_stadium_review UNIQUE (user_id, stadium_id);

-- 3. Exception-safe pg_cron cleanups (removes any previous conflicting jobs safely)
DELETE FROM cron.job 
WHERE jobname IN ('expire-challenges-hourly', 'expire-challenges-every-hour', 'expire-unconfirmed-bookings-every-2-minutes');

-- 4. Create universal 15-minute booking auto-expiry function
CREATE OR REPLACE FUNCTION public.auto_expire_unconfirmed_bookings()
RETURNS void AS $$
BEGIN
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Cancelled due to 15-minute P2P payment timeout]'
  WHERE 
    status = 'pending'
    AND created_at <= NOW() - INTERVAL '15 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Schedule 15-minute auto-expiry to run every 2 minutes
SELECT cron.schedule(
  'expire-unconfirmed-bookings-every-2-minutes',
  '*/2 * * * *',
  'SELECT public.auto_expire_unconfirmed_bookings();'
);

-- 6. Exception-safe real-time publication setup for critical tables
DO $$
DECLARE
    pub_exists boolean;
    tables_to_add text[] := ARRAY['users', 'bookings', 'chat_messages'];
    t text;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') INTO pub_exists;
    IF NOT pub_exists THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;

    FOREACH t IN ARRAY tables_to_add LOOP
        IF EXISTS (
            SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relname = t
        ) THEN
            IF NOT EXISTS (
                SELECT 1 FROM pg_publication_rel pr JOIN pg_class c ON c.oid = pr.prrelid JOIN pg_publication p ON p.oid = pr.prpubid
                WHERE p.pubname = 'supabase_realtime' AND c.relname = t
            ) THEN
                EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
            END IF;
        END IF;
    END LOOP;
END $$;
