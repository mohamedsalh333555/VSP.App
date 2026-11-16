-- Realtime subscription support for the existing VSP notification inbox.
-- Flutter NotificationRepository.stream() requires the table in the
-- supabase_realtime publication to receive live INSERT/UPDATE changes.
-- Only this single notifications table is added; Team Skills scores and
-- private judge/keeper data are deliberately NOT published.
-- Production rollout requires review of volume and RLS/JWT E2E separately.
do $publish$
declare v_notification_table oid; v_pub oid;
begin
 select c.oid into v_notification_table
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname='notifications'
   and c.relkind='r' and c.relrowsecurity;
 if v_notification_table is null then
   raise exception 'Notifications table must exist with RLS enabled';
 end if;

 if not exists(
   select 1 from pg_policies p
   where p.schemaname='public' and p.tablename='notifications'
     and p.cmd='SELECT' and 'authenticated'=any(p.roles)
     and position('user_id' in p.qual)>0
     and position('auth.uid()' in p.qual)>0
 ) then raise exception 'Owner-scoped notification SELECT RLS policy missing';end if;

 select oid into v_pub from pg_publication where pubname='supabase_realtime';
 if v_pub is null then raise exception 'Supabase Realtime publication missing';end if;

 if not exists(
   select 1 from pg_publication_rel
   where prpubid=v_pub and prrelid=v_notification_table
 ) then
   execute 'alter publication supabase_realtime add table public.notifications';
 end if;
end $publish$;
