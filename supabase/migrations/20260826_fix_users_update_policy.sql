-- Fix: Add users UPDATE policy and complete admin profile

DROP POLICY IF EXISTS "users_update_policy" ON public.users;

CREATE POLICY "users_update_policy" ON public.users 
FOR UPDATE TO authenticated 
USING (auth.uid() = id) 
WITH CHECK (auth.uid() = id);

-- Ensure all current users have verified emails and complete registration flags where applicable
UPDATE public.users 
SET is_registration_complete = true, is_email_verified = true 
WHERE email = 'admin@vsp.com';
