-- Persist the UI payload required to reconstruct Copilot messages after reopening a conversation.
alter table public.copilot_messages
  add column if not exists ui_metadata jsonb not null default '{}'::jsonb;

comment on column public.copilot_messages.ui_metadata is
  'Persistent UI/action/clarification metadata for VSP Copilot conversation replay.';
