-- Restore safe client-side notification inserts for self and real booking participants.
-- The live database currently has only the admin-only INSERT policy, which blocks
-- legitimate player/owner cancellation notifications created by the app client.
DROP POLICY IF EXISTS notifications_insert_admin_only ON public.notifications;
DROP POLICY IF EXISTS notifications_insert_secure ON public.notifications;

CREATE POLICY notifications_insert_secure
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (
  public.is_admin_or_cofounder((select auth.uid()))
  OR user_id = (select auth.uid())
  OR (
    booking_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.bookings AS b
      WHERE b.id = notifications.booking_id
        AND (
          b.user_id = (select auth.uid())
          OR b.owner_id = (select auth.uid())
          OR b.created_by_user_id = (select auth.uid())
          OR (select auth.uid()) = ANY(coalesce(b.joined_user_ids, ARRAY[]::uuid[]))
        )
        AND (
          notifications.user_id = b.user_id
          OR notifications.user_id = b.owner_id
          OR notifications.user_id = b.created_by_user_id
          OR notifications.user_id = ANY(coalesce(b.joined_user_ids, ARRAY[]::uuid[]))
        )
    )
  )
);
