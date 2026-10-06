alter function public.vsp_validate_stadium_booking_window(time,time,time,time,boolean,timestamptz,timestamptz,timestamptz) set search_path = public, pg_temp;
drop index if exists public.idx_system_audit_logs_changed_by;
drop index if exists public.idx_system_audit_logs_created_at;