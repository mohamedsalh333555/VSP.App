-- Notification recipient guard -- 2026-09-26
-- Only admins, self, or actual booking participants may be notification recipients
-- when the caller is a participant in the same booking.
drop policy if exists notifications_insert_secure on public.notifications;
create policy notifications_insert_secure
on public.notifications for insert to authenticated
with check (
  public.is_admin_or_cofounder(auth.uid())
  or user_id=auth.uid()
  or (
    booking_id is not null
    and exists (
      select 1 from public.bookings b
      where b.id=notifications.booking_id
        and (
          b.user_id=auth.uid()
          or b.owner_id=auth.uid()
          or b.created_by_user_id=auth.uid()
          or auth.uid()=any(coalesce(b.joined_user_ids,array[]::uuid[]))
        )
        and (
          notifications.user_id=b.user_id
          or notifications.user_id=b.owner_id
          or notifications.user_id=b.created_by_user_id
          or notifications.user_id=any(coalesce(b.joined_user_ids,array[]::uuid[]))
        )
    )
  )
);