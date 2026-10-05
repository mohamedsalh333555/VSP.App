-- Return the full server-authoritative owner web checkout price breakdown.
create or replace function public.get_owner_subscription_checkout_status(p_order_id uuid)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (
      select jsonb_build_object(
        'success',true,
        'status',o.status,
        'plan_code',o.plan_code,
        'billing_period',o.billing_period,
        'amount',o.amount,
        'base_amount',o.amount,
        'vsp_fee_amount',o.vsp_fee_amount,
        'paymob_fee_amount',o.paymob_fee_amount,
        'gross_amount',coalesce(o.gross_amount,o.amount),
        'paid_at',o.paid_at,
        'payment_source',o.payment_source
      )
      from public.owner_subscription_orders o
      where o.id=p_order_id
    ),
    jsonb_build_object('success',false,'error','ORDER_NOT_FOUND')
  );
$$;

revoke execute on function public.get_owner_subscription_checkout_status(uuid) from public;
revoke execute on function public.get_owner_subscription_checkout_status(uuid) from anon;
revoke execute on function public.get_owner_subscription_checkout_status(uuid) from authenticated;
grant execute on function public.get_owner_subscription_checkout_status(uuid) to service_role;
