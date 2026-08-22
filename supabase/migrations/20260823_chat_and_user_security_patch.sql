-- ==============================================================================
-- VSP SECURITY & INTEGRITY PATCH (PASS 2 - SERVER SIDE)
-- File: supabase/migrations/20260823_chat_and_user_security_patch.sql
-- ==============================================================================

-- 1. 🔴 FIX C2: Prevent Chat Sender Spoofing (Enforce real user name)
CREATE OR REPLACE FUNCTION enforce_real_sender_name()
RETURNS TRIGGER AS $$
BEGIN
  -- Force the sender_id to be the authenticated user
  NEW.sender_id := auth.uid();
  -- Fetch and force the real name from the users table
  SELECT name INTO NEW.sender_name FROM public.users WHERE id = auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_sender_name ON public.chat_messages;
CREATE TRIGGER trg_enforce_sender_name
BEFORE INSERT ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION enforce_real_sender_name();

-- 2. 🔴 FIX C4 & C3: Lock Down Sensitive User Fields (verification_status, balance, etc.)
CREATE OR REPLACE FUNCTION lock_sensitive_user_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- If the user making the update is NOT an admin/co-founder
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')) THEN
    -- Revert any attempts to change these specific fields manually by the client
    NEW.verification_status := OLD.verification_status;
    NEW.is_identity_verified := OLD.is_identity_verified;
    NEW.is_blocked := OLD.is_blocked;
    NEW.role := OLD.role;
    NEW.is_registration_complete := OLD.is_registration_complete;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_lock_sensitive_fields ON public.users;
CREATE TRIGGER trg_lock_sensitive_fields
BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION lock_sensitive_user_fields();

-- 3. 🔴 FIX C5: Atomic Array Append for Chat Deletion (Fixes Race Condition)
CREATE OR REPLACE FUNCTION delete_chat_for_user_atomic(p_booking_id UUID, p_user_id UUID)
RETURNS void AS $$
BEGIN
  -- Atomically append the user_id to the array in chat_messages ONLY if it's not already there
  UPDATE public.chat_messages
  SET deleted_for_users = ARRAY(SELECT DISTINCT UNNEST(array_append(deleted_for_users, p_user_id)))
  WHERE booking_id = p_booking_id 
    AND NOT (deleted_for_users @> ARRAY[p_user_id]);

  -- Atomically append to conversations table
  UPDATE public.conversations
  SET deleted_for_users = ARRAY(SELECT DISTINCT UNNEST(array_append(deleted_for_users, p_user_id)))
  WHERE booking_id = p_booking_id 
    AND NOT (deleted_for_users @> ARRAY[p_user_id]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
