create or replace function public.delete_stadium_for_owner(p_stadium_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_uid uuid:=auth.uid(); v_role text; v_owner uuid; v_active int;
begin
 if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
 select owner_id into v_owner from public.stadiums where id=p_stadium_id for update;
 if not found then raise exception 'الملعب غير موجود'; end if;
 select role into v_role from public.users where id=v_uid;
 if v_owner<>v_uid and coalesce(v_role,'') not in ('admin','co_founder','super_admin','cofounder') then raise exception 'غير مصرح بحذف هذا الملعب'; end if;
 select count(*) into v_active from public.bookings where stadium_id=p_stadium_id and status<>'cancelled' and start_time>=now();
 if v_active>0 then raise exception 'لا يمكن حذف الملعب لوجود حجوزات حالية أو مستقبلية'; end if;
 update public.stadiums set is_deleted_by_owner=true,is_verified=false,is_blocked=true,updated_at=now() where id=p_stadium_id;
 return jsonb_build_object('success',true,'stadium_id',p_stadium_id,'deleted',true);
end;
$$;
revoke execute on function public.delete_stadium_for_owner(uuid) from public,anon;
grant execute on function public.delete_stadium_for_owner(uuid) to authenticated;