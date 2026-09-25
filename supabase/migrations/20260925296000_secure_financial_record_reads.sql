-- Owner/admin read access only for financial records.
alter table public.transactions enable row level security;
alter table public.payout_settlements enable row level security;
create policy "transactions_owner_or_admin_select" on public.transactions
for select to authenticated
using (
  user_id = auth.uid()
  or exists (select 1 from public.bookings b where b.id=transactions.booking_id and b.owner_id=auth.uid())
  or exists (select 1 from public.users u where u.id=auth.uid() and u.role in ('admin','co_founder','cofounder','super_admin'))
);
create policy "payout_settlements_owner_or_admin_select" on public.payout_settlements
for select to authenticated
using (
 owner_id=auth.uid()
 or exists (select 1 from public.users u where u.id=auth.uid() and u.role in ('admin','co_founder','cofounder','super_admin'))
);