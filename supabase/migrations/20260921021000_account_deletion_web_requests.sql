create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  email text not null check (length(trim(email)) between 3 and 320),
  phone text not null check (length(trim(phone)) between 8 and 20),
  details text check (details is null or length(details) <= 2000),
  status text not null default 'pending' check (status in ('pending','verified','completed','rejected')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.account_deletion_requests enable row level security;

drop policy if exists "anon_can_submit_account_deletion_request" on public.account_deletion_requests;
create policy "anon_can_submit_account_deletion_request"
on public.account_deletion_requests
for insert to anon, authenticated
with check (
  length(trim(email)) between 3 and 320
  and length(trim(phone)) between 8 and 20
  and (details is null or length(details) <= 2000)
  and status = 'pending'
);

revoke all on public.account_deletion_requests from anon, authenticated;
grant insert on public.account_deletion_requests to anon, authenticated;
grant select, insert, update, delete on public.account_deletion_requests to service_role;