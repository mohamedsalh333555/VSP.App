-- Owner web checkout hardening: persist checkout name and keep status RPC server-only.
alter table public.owner_subscription_orders
  add column if not exists checkout_name text;

revoke execute on function public.get_owner_subscription_checkout_status(uuid) from public;
revoke execute on function public.get_owner_subscription_checkout_status(uuid) from anon;
revoke execute on function public.get_owner_subscription_checkout_status(uuid) from authenticated;
grant execute on function public.get_owner_subscription_checkout_status(uuid) to service_role;
