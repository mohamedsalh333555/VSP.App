-- Store readiness: UGC user blocking with DB-enforced access control
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  check (blocker_id <> blocked_user_id)
);
alter table public.user_blocks enable row level security;
drop policy if exists user_blocks_select_own on public.user_blocks;
create policy user_blocks_select_own on public.user_blocks for select to authenticated using (blocker_id=auth.uid());
drop policy if exists user_blocks_insert_own on public.user_blocks;
create policy user_blocks_insert_own on public.user_blocks for insert to authenticated with check (blocker_id=auth.uid() and blocked_user_id<>auth.uid());
drop policy if exists user_blocks_delete_own on public.user_blocks;
create policy user_blocks_delete_own on public.user_blocks for delete to authenticated using (blocker_id=auth.uid());

create or replace function public.are_users_blocked(p_user_a uuid,p_user_b uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
select exists(select 1 from public.user_blocks where (blocker_id=p_user_a and blocked_user_id=p_user_b) or (blocker_id=p_user_b and blocked_user_id=p_user_a));
$$;
create or replace function public.block_user_atomic(p_blocked_user_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); end if;
 if p_blocked_user_id is null or p_blocked_user_id=auth.uid() then return jsonb_build_object('success',false,'error','INVALID_TARGET'); end if;
 if not exists(select 1 from public.users where id=p_blocked_user_id) then return jsonb_build_object('success',false,'error','USER_NOT_FOUND'); end if;
 insert into public.user_blocks(blocker_id,blocked_user_id) values(auth.uid(),p_blocked_user_id) on conflict do nothing;
 return jsonb_build_object('success',true);
end $$;
create or replace function public.unblock_user_atomic(p_blocked_user_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); end if;
 delete from public.user_blocks where blocker_id=auth.uid() and blocked_user_id=p_blocked_user_id;
 return jsonb_build_object('success',true);
end $$;
revoke execute on function public.are_users_blocked(uuid,uuid) from public,anon;
revoke execute on function public.block_user_atomic(uuid) from public,anon;
revoke execute on function public.unblock_user_atomic(uuid) from public,anon;
grant execute on function public.are_users_blocked(uuid,uuid) to authenticated,service_role;
grant execute on function public.block_user_atomic(uuid) to authenticated,service_role;
grant execute on function public.unblock_user_atomic(uuid) to authenticated,service_role;