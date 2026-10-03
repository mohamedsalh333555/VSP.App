-- Enable the 1v1 registration gate after switching the Paymob account to Test Mode.
UPDATE public.app_config
SET vsp_1v1_is_open = true
WHERE id = 1;
