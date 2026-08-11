-- ==============================================================================
-- 🏆 VSP MIGRATION 202608110005: SUPABASE QUEUES (PGMQ) FOR ASYNC NOTIFICATIONS
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgmq;

-- Create notifications queue
SELECT pgmq.create('notifications_queue');

-- Function to enqueue notification message upon insert into public.notifications table
CREATE OR REPLACE FUNCTION public.enqueue_notification_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM pgmq.send(
    'notifications_queue',
    jsonb_build_object(
      'notification_id', NEW.id,
      'user_id', NEW.user_id,
      'title', NEW.title,
      'body', NEW.body,
      'type', NEW.type,
      'booking_id', NEW.booking_id,
      'created_at', NEW.created_at
    )
  );
  RETURN NEW;
END;
$$;

-- Trigger definition
DROP TRIGGER IF EXISTS trigger_enqueue_notification ON public.notifications;
CREATE TRIGGER trigger_enqueue_notification
AFTER INSERT ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.enqueue_notification_trigger();
