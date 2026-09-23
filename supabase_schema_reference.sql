-- VSP production schema reference.
-- Generated from the live Supabase project when a complete DDL snapshot is required.
-- This file is documentation only and must never be executed as a migration.

-- Table inventory:
select
  table_name,
  table_type
from information_schema.tables
where table_schema = 'public'
order by table_name;

-- Column inventory:
select
  table_name,
  ordinal_position,
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
order by table_name, ordinal_position;

-- RLS policy inventory:
select
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- Function inventory:
select
  p.oid::regprocedure as signature,
  p.prosecdef as security_definer,
  n.nspname as schema_name
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by 1;
