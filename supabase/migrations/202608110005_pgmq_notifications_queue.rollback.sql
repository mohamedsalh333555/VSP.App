-- ==============================================================================
-- 🏆 ROLLBACK FOR MIGRATION 202608110005: PGMQ NOTIFICATIONS QUEUE
-- ==============================================================================

DROP TRIGGER IF EXISTS trigger_enqueue_notification ON public.notifications;
DROP FUNCTION IF EXISTS public.enqueue_notification_trigger();
SELECT pgmq.drop_queue('notifications_queue');
