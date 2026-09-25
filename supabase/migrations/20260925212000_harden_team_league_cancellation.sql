create or replace function public.cancel_team_league(p_championship_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_uid uuid:=auth.uid(); v_owner uuid; v_paid_count int; v_status text;
begin
 if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
 select owner_id,status,cardinality(coalesce(paid_teams,'{}'::text[])) into v_owner,v_status,v_paid_count
 from public.championships where id=p_championship_id and template_type='team_league' for update;
 if not found then raise exception 'الدوري غير موجود'; end if;
 if v_owner<>v_uid then raise exception 'فقط منشئ الدوري يستطيع إلغاءه'; end if;
 if v_status<>'open' then raise exception 'لا يمكن إلغاء الدوري بعد بدء المنافسات'; end if;
 if v_paid_count>0 then raise exception 'لا يمكن إلغاء الدوري بعد وجود فرق دفعت الرسوم؛ يلزم معالجة الاسترداد أولاً'; end if;
 delete from public.championships where id=p_championship_id;
 return jsonb_build_object('success',true,'message','تم إلغاء الدوري');
end;
$$;
revoke execute on function public.cancel_team_league(uuid) from public,anon;
grant execute on function public.cancel_team_league(uuid) to authenticated;