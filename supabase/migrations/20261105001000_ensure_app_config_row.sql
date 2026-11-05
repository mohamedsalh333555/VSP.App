-- The Flutter bootstrap requires one canonical app_config row. Keep this
-- idempotent so fresh staging projects and production upgrades share the same
-- deterministic startup contract.

insert into public.app_config (
  id,
  is_maintenance,
  min_version,
  vsp_1v1_is_open,
  vsp_1v1_link
)
values (1, false, '1.0.0', true, null)
on conflict (id) do nothing;

