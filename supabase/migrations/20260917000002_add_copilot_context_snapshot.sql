-- Migration: 20260917000002_add_copilot_context_snapshot.sql
-- Description: Add context_snapshot JSONB column to copilot_conversations for multi-turn state tracking

ALTER TABLE IF EXISTS public.copilot_conversations
ADD COLUMN IF NOT EXISTS context_snapshot jsonb DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.copilot_conversations.context_snapshot IS 
'Stores conversation state machine snapshot: last_stadium_id, last_date, preferred_surface, max_price, pending_booking_slot';
