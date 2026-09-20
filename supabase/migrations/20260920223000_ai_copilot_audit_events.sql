-- AI Copilot observability and verification audit trail.
-- This migration mirrors the schema already applied to production on 2026-09-20.

create table if not exists public.ai_copilot_audit_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  conversation_id uuid null references public.copilot_conversations(id) on delete set null,
  user_id uuid null references auth.users(id) on delete set null,
  user_role text not null,
  event_type text not null check (
    event_type in (
      'request_started',
      'tool_completed',
      'security_rejected',
      'action_emitted',
      'response_completed',
      'request_failed'
    )
  ),
  capability_id text null,
  tool_name text null,
  action_type text null,
  status text not null,
  verified boolean not null default false,
  verification_source text null,
  error_code text null,
  request_hash text null,
  latency_ms integer null check (latency_ms is null or latency_ms >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ai_copilot_audit_events_request_idx
  on public.ai_copilot_audit_events(request_id, created_at);

create index if not exists ai_copilot_audit_events_user_idx
  on public.ai_copilot_audit_events(user_id, created_at desc);

create index if not exists ai_copilot_audit_events_event_idx
  on public.ai_copilot_audit_events(event_type, created_at desc);

alter table public.ai_copilot_audit_events enable row level security;

revoke all on table public.ai_copilot_audit_events from public, anon, authenticated;

create or replace function public.record_ai_copilot_audit_event(
  p_request_id uuid,
  p_conversation_id uuid,
  p_user_id uuid,
  p_user_role text,
  p_event_type text,
  p_status text,
  p_capability_id text default null,
  p_tool_name text default null,
  p_action_type text default null,
  p_verified boolean default false,
  p_verification_source text default null,
  p_error_code text default null,
  p_request_hash text default null,
  p_latency_ms integer default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id uuid;
begin
  insert into public.ai_copilot_audit_events (
    request_id, conversation_id, user_id, user_role, event_type, status,
    capability_id, tool_name, action_type, verified, verification_source,
    error_code, request_hash, latency_ms, metadata
  ) values (
    p_request_id, p_conversation_id, p_user_id,
    lower(coalesce(trim(p_user_role), 'unknown')),
    p_event_type, p_status,
    nullif(upper(trim(coalesce(p_capability_id, ''))), ''),
    nullif(trim(coalesce(p_tool_name, '')), ''),
    nullif(upper(trim(coalesce(p_action_type, ''))), ''),
    coalesce(p_verified, false),
    nullif(trim(coalesce(p_verification_source, '')), ''),
    nullif(trim(coalesce(p_error_code, '')), ''),
    nullif(trim(coalesce(p_request_hash, '')), ''),
    p_latency_ms,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$function$;

revoke execute on function public.record_ai_copilot_audit_event(
  uuid, uuid, uuid, text, text, text, text, text, text, boolean, text, text, text, integer, jsonb
) from public, anon, authenticated;

grant execute on function public.record_ai_copilot_audit_event(
  uuid, uuid, uuid, text, text, text, text, text, text, boolean, text, text, text, text, jsonb
) to service_role;
