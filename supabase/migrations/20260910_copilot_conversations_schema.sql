-- ==============================================================================
-- 🔒 VSP MIGRATION 20260910: COPILOT CONVERSATIONS & MULTI-TURN MESSAGES SCHEMA
-- Description: Dedicated conversation sessions and message history for VSP Copilot
-- Security: Strict Row Level Security (RLS) enforcing auth.uid() = user_id
-- ==============================================================================

-- 1. Table: copilot_conversations
CREATE TABLE IF NOT EXISTS public.copilot_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'محادثة جديدة',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_copilot_conversations_user 
ON public.copilot_conversations(user_id, updated_at DESC);

ALTER TABLE public.copilot_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS copilot_conversations_user_policy ON public.copilot_conversations;
CREATE POLICY copilot_conversations_user_policy ON public.copilot_conversations
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. Table: copilot_messages
CREATE TABLE IF NOT EXISTS public.copilot_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.copilot_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    stadium_results JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_copilot_messages_conv 
ON public.copilot_messages(conversation_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_copilot_messages_user 
ON public.copilot_messages(user_id, created_at DESC);

ALTER TABLE public.copilot_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS copilot_messages_user_policy ON public.copilot_messages;
CREATE POLICY copilot_messages_user_policy ON public.copilot_messages
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. Grants
GRANT ALL ON public.copilot_conversations TO authenticated;
GRANT ALL ON public.copilot_conversations TO service_role;
GRANT ALL ON public.copilot_messages TO authenticated;
GRANT ALL ON public.copilot_messages TO service_role;
