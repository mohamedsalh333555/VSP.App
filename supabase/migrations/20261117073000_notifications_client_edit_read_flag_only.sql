-- An authenticated client may mark its own notifications as read/unread,
-- but may never change payment/tournament event content, recipient or
-- booking correlation. A trusted service-role/server trigger may still
-- write messages. Existing SELECT/INSERT/UPDATE RLS remains in effect.
create or replace function vsp_notifications_private.guard_client_notification_edits()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.role(),'')='authenticated' and (
    new.user_id is distinct from old.user_id
    or new.title is distinct from old.title
    or new.body is distinct from old.body
    or new.message is distinct from old.message
    or new.type is distinct from old.type
    or new.booking_id is distinct from old.booking_id
    or new.metadata is distinct from old.metadata
    or new.created_at is distinct from old.created_at
  ) then
    raise exception 'NOTIFICATION_CLIENT_CONTENT_IMMUTABLE'
      using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function vsp_notifications_private.guard_client_notification_edits()
 from public,anon,authenticated;
drop trigger if exists trg_guard_client_notification_edits
 on public.notifications;
create trigger trg_guard_client_notification_edits
before update on public.notifications
for each row execute function
 vsp_notifications_private.guard_client_notification_edits();
