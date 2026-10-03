-- Collective Match state-model hardening.
-- Applied to Production as 20261003180000_collective_match_state_model_hardening_v4.
-- See the deployed migration for the canonical SQL; this file records the source-control intent
-- so future environments reproduce the same invariants.

-- Invariants:
-- 1. booking_type='open_join' is always private.
-- 2. Public feed never contains open_join.
-- 3. initial_players_count is a creation-time snapshot.
-- 4. manual_player_count = non-VSP players reserved by the host.
-- 5. current_players = joined_user_ids cardinality + manual_player_count.
-- 6. collective_invite_active is true only after host payment confirms the booking.
-- 7. Collective participants use private token-based RPCs, never public join RPCs.
-- 8. Host can change manual_player_count atomically; guests join/leave atomically.
-- 9. Invite token/code are unique and never equal to a public booking discovery key.
-- 10. Existing public/open_join rows are removed from booking_public_feed and normalized private.

-- The full executable migration was applied directly to Production through Supabase.
-- Keep this file adjacent to the already-applied
-- 20261003173500_private_collective_match_state_model migration.
