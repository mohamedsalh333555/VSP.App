# VSP staging — privileged RPC inventory (read-only)

Audit date: 2026-11-13 (UTC). Project: `vsp-staging` (`vtwgqyxglevcsxwdmhop`). Source: `pg_proc`, `pg_namespace`, `has_function_privilege` and Supabase Security Advisor; **no function invocation or permission mutation**.

## Scope and counts

- `public` SECURITY DEFINER routines executable by `authenticated`: **200** (historic issue #38: 198; count changed).
- `anon` execution among these: **0**.
- Supabase Security Advisor alert `authenticated_security_definer_function_executable`: **200**.
- **Warning != exploit**. Each routine requires review of grants, internal authorization and caller-controlled parameters before any permission change. No blanket revocation or `SECURITY INVOKER` conversion.

## Exact function signatures (schema `public`)

1. `accept_join_request(text,text)`
2. `activate_championship_competition_atomic(uuid)`
3. `activate_vsp_pro(text,text,integer)`
4. `add_team_member_atomic(uuid,uuid)`
5. `add_team_to_matchup_by_code(uuid,text)`
6. `admin_add_1v1_cash_player_atomic(uuid,text,uuid,numeric)`
7. `admin_approve_1v1_registration_atomic(uuid,text,text)`
8. `admin_approve_championship_atomic(uuid)`
9. `admin_approve_owner_atomic(uuid)`
10. `admin_cancel_booking_atomic(uuid,text)`
11. `admin_create_1v1_tournament_atomic(text,integer,numeric,timestamp with time zone,text,numeric)`
12. `admin_create_owner_with_stadium_atomic(text,text,text,text,text,numeric)`
13. `admin_finalize_1v1_tournament_atomic(uuid,uuid)`
14. `admin_get_1v1_round_scores(uuid,integer)`
15. `admin_publish_legacy_1v1_standings_atomic(jsonb)`
16. `admin_record_payout_settlement_atomic(uuid,numeric,text,text)`
17. `admin_register_owner_on_behalf(text,text,text,text,text)`
18. `admin_reject_1v1_registration_atomic(uuid)`
19. `admin_reject_championship_atomic(uuid,text)`
20. `admin_reject_owner_atomic(uuid,text)`
21. `admin_reset_1v1_round_atomic()`
22. `admin_reset_no_show_count_atomic(uuid)`
23. `admin_resolve_dispute_atomic(uuid,text,integer,integer,text)`
24. `admin_resolve_report_atomic(uuid,text,text)`
25. `admin_save_1v1_tournament_players_atomic(uuid,jsonb)`
26. `admin_send_broadcast_notification_atomic(text,text,text,text)`
27. `admin_set_1v1_registration_open_atomic(boolean)`
28. `admin_set_admin_role_atomic(uuid,text)`
29. `admin_set_maintenance_mode_atomic(boolean)`
30. `admin_set_owner_subscription_atomic(uuid,text,integer)`
31. `admin_settle_owner_cash_debt_atomic(uuid,numeric,text)`
32. `admin_toggle_user_block(uuid,boolean)`
33. `admin_update_1v1_player_stats_atomic(uuid,integer,integer,integer,integer,integer,text)`
34. `admin_update_1v1_tournament_atomic(uuid,text,integer,numeric,timestamp with time zone,text,numeric)`
35. `admin_update_1v1_tournament_status_atomic(uuid,text)`
36. `admin_update_1v1_tournament_status(uuid,text,uuid)`
37. `admin_update_booking_safe_atomic(uuid,jsonb)`
38. `admin_update_championship_status_atomic(uuid,text,text)`
39. `admin_update_support_ticket_atomic(uuid,text,text,uuid)`
40. `admin_upgrade_owner_subscription_atomic(uuid,text,integer)`
41. `admin_wipe_1v1_data_atomic()`
42. `advance_groups_to_knockout_atomic(uuid)`
43. `apply_no_show_penalty(uuid)`
44. `approve_payout_settlement_atomic(uuid,text)`
45. `are_users_blocked(uuid,uuid)`
46. `block_user_atomic(uuid)`
47. `cancel_1v1_payment_order_atomic(text)`
48. `cancel_1v1_tournament_with_refund_requests(uuid,text)`
49. `cancel_booking_with_refund_atomic(uuid,text)`
50. `cancel_booking_with_refund_atomic(uuid,uuid,text)`
51. `cancel_championship_atomic(uuid,text)`
52. `cancel_incomplete_registration_atomic(uuid)`
53. `cancel_team_league(uuid)`
54. `cancel_tournament_payment_order_atomic(text)`
55. `check_extension_available(uuid,timestamp with time zone)`
56. `check_owner_stadium_limit(uuid)`
57. `check_rate_limit(uuid,text,integer,integer)`
58. `claim_owner_championship_approval_home_notice(uuid)`
59. `claim_owner_web_subscription()`
60. `cleanup_stale_pending_bookings_atomic(uuid,uuid)`
61. `close_matchup_atomic(uuid)`
62. `close_owner_daily_shift(uuid,uuid,date)`
63. `complete_user_registration(uuid,text,text,text,text,text,text,text,text)`
64. `confirm_1v1_payment_atomic(text,text,numeric)`
65. `confirm_cash_booking_atomic(uuid,uuid,numeric,numeric)`
66. `confirm_matchup_atomic(uuid)`
67. `confirm_owner_onboarding(uuid)`
68. `confirm_team_league_match_result(uuid,text)`
69. `confirm_tournament_order_atomic(text,text)`
70. `create_1v1_payment_order_atomic(uuid)`
71. `create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer)`
72. `create_challenge_booking_atomic(text,text,timestamp with time zone,timestamp with time zone,text,boolean,text)`
73. `create_championship_atomic(text,uuid,text,text,numeric,numeric,integer,integer,integer,timestamp with time zone,timestamp with time zone,timestamp with time zone,text,text,text,jsonb)`
74. `create_direct_chat_atomic(uuid,text,uuid)`
75. `create_owner_on_behalf(text,text,text,text,text)`
76. `create_owner_subscription_order(text,text)`
77. `create_report_atomic(text,uuid,text,text,text,uuid,uuid,uuid)`
78. `create_support_ticket_atomic(text,text,text,uuid,uuid,text)`
79. `create_team_league(text,uuid,text,integer,integer,text,integer)`
80. `create_team_with_consent(jsonb,uuid[])`
81. `create_tournament_order_atomic(uuid,uuid,uuid[],text[],text)`
82. `crown_individual_1v1_champion(uuid,uuid,numeric)`
83. `crown_tournament_champion_atomic(uuid,uuid,text)`
84. `delete_championship_atomic(uuid)`
85. `delete_chat_for_user_atomic(uuid,uuid)`
86. `delete_chat_for_user(uuid,uuid)`
87. `delete_stadium_for_owner(uuid)`
88. `delete_team_atomic(uuid)`
89. `delete_user_permanently(uuid)`
90. `dismiss_no_show_penalty(uuid,uuid)`
91. `dispute_no_show_with_gps(text,text,numeric,numeric,numeric)`
92. `edit_chat_message_atomic(uuid,text)`
93. `evaluate_owner_stadium_capacity(uuid,uuid)`
94. `generate_booking_qr_token(uuid)`
95. `generate_regular_group_fixtures_atomic(uuid)`
96. `generate_regular_league_fixtures_atomic(uuid)`
97. `generate_team_challenge_code(uuid)`
98. `generate_team_invite_code(uuid)`
99. `generate_tournament_bracket_atomic(uuid)`
100. `get_admin_metrics()`
101. `get_admin_quick_metrics()`
102. `get_championship_actions(uuid)`
103. `get_collective_invite_credentials(uuid)`
104. `get_current_user_role(uuid)`
105. `get_owner_ai_operational_insights(uuid,text)`
106. `get_owner_ai_stadium_comparison(uuid,text)`
107. `get_owner_dashboard_analytics(uuid,timestamp with time zone,timestamp with time zone,uuid)`
108. `get_owner_financial_summary(uuid)`
109. `get_owner_trial_state()`
110. `get_platform_business_rules()`
111. `get_player_match_details(uuid)`
112. `get_player_my_bookings_atomic(uuid)`
113. `get_private_collective_invite_by_code(text)`
114. `get_private_collective_invite_details(text)`
115. `get_private_collective_match_details(uuid)`
116. `get_public_match_details(uuid)`
117. `get_server_timestamp()`
118. `get_team_active_league(uuid)`
119. `get_team_invite_code(uuid)`
120. `get_team_league_payment_status(uuid,uuid)`
121. `get_team_league_standings(uuid)`
122. `get_team_member_profiles(uuid)`
123. `get_tournament_financial_summary(uuid)`
124. `get_tournament_payment_order_status(text)`
125. `global_search(text)`
126. `increment_banner_clicks(uuid)`
127. `increment_banner_views(uuid)`
128. `increment_chat_unread_count(text,text,text)`
129. `invite_team_member(uuid,uuid)`
130. `is_admin_or_cofounder(uuid)`
131. `join_1v1_tournament_atomic(uuid)`
132. `join_championship_atomic(uuid,uuid,uuid[],text[])`
133. `join_private_collective_match_atomic(text,uuid)`
134. `join_team_league(uuid,uuid)`
135. `leave_1v1_tournament_atomic(uuid)`
136. `leave_championship_atomic(uuid,uuid)`
137. `leave_private_collective_match_atomic(uuid,uuid)`
138. `leave_public_match_atomic(uuid,uuid)`
139. `link_league_match_booking(uuid,uuid,timestamp with time zone,text)`
140. `lookup_challenge_code(text)`
141. `mark_1v1_prize_delivered_atomic(uuid,text)`
142. `mark_championship_prize_delivered_atomic(uuid,text)`
143. `mark_chat_messages_as_read(uuid,uuid)`
144. `mark_support_ticket_whatsapp_escalation(uuid)`
145. `owner_cancel_manual_booking_atomic(uuid,uuid,boolean)`
146. `owner_create_manual_booking_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text,text,text,numeric,numeric,integer)`
147. `owner_extend_match_atomic(uuid,integer)`
148. `owner_lock_slot_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text)`
149. `owner_record_no_show_atomic(uuid,uuid,text)`
150. `owner_update_manual_booking_atomic(uuid,timestamp with time zone,text,text,text,integer,numeric)`
151. `pay_rehabilitation_fine(uuid)`
152. `persist_copilot_turn(uuid,uuid,text,text,jsonb,jsonb,jsonb)`
153. `prepare_team_league_payment(uuid,uuid)`
154. `prepare_tournament_bracket_atomic(uuid)`
155. `provision_registration_profile(text)`
156. `publish_1v1_final_standings_atomic(uuid)`
157. `record_match_result_and_advance_atomic(uuid,integer,integer,integer,integer,uuid,text,jsonb)`
158. `record_matchup_result_atomic(uuid,uuid,uuid,text)`
159. `reject_join_request(text,text)`
160. `reject_payout_settlement_atomic(uuid,text)`
161. `release_booking_lock(uuid)`
162. `remove_private_collective_participant_atomic(uuid,uuid)`
163. `remove_public_match_participant_atomic(uuid,uuid)`
164. `remove_team_member_atomic(uuid,uuid)`
165. `remove_tournament_team_atomic(uuid,uuid)`
166. `request_booking_reschedule_atomic(uuid,timestamp with time zone,timestamp with time zone)`
167. `request_emergency_stadium_closure(uuid,uuid,text,integer)`
168. `request_join_public_match(text,text)`
169. `request_owner_payout_settlement_atomic(uuid,numeric,text,text)`
170. `respond_booking_reschedule_atomic(uuid,boolean)`
171. `respond_team_membership_invitation(uuid,boolean)`
172. `save_and_publish_1v1_tournament_atomic(uuid,jsonb,uuid)`
173. `send_chat_message_atomic(uuid,text)`
174. `send_support_ticket_message_atomic(uuid,text)`
175. `set_user_role_on_signup(text,uuid)`
176. `start_championship_atomic(uuid)`
177. `start_owner_trial()`
178. `submit_challenge_result_atomic(uuid,uuid,text)`
179. `submit_owner_verification(uuid,jsonb)`
180. `submit_stadium_review_atomic(uuid,uuid,integer,text,text,text)`
181. `submit_team_league_match_result(uuid,uuid,text)`
182. `transfer_team_captaincy_atomic(uuid,uuid)`
183. `transition_championship_status_atomic(uuid,text)`
184. `unblock_user_atomic(uuid)`
185. `update_championship_atomic(uuid,jsonb)`
186. `update_championship_roster_atomic(uuid,uuid,uuid[],text[])`
187. `update_collective_manual_players_atomic(uuid,uuid,integer)`
188. `update_host_spots_atomic(uuid,uuid,integer)`
189. `update_onboarding_confirmed_atomic(uuid,boolean)`
190. `update_owner_onboarding_atomic(uuid,jsonb)`
191. `update_owner_verification_document(uuid,text,text)`
192. `update_team_atomic(uuid,jsonb)`
193. `update_tournament_match_schedule_atomic(uuid,timestamp with time zone)`
194. `verify_booking_qr_atomic(uuid,text)`
195. `verify_match_played(uuid,boolean,text)`
196. `vsp_chat_write_allowed(uuid,uuid)`
197. `vsp_enforce_booking_operating_window()`
198. `vsp_is_admin_actor()`
199. `vsp_user_is_tournament_participant(uuid,uuid)`
200. `withdraw_team_from_championship_atomic(uuid,uuid,text)`

## Required follow-ups

Trace each callable routine to Flutter/Edge Function/triggers/migrations, categorize admin/payment/booking/content risks, test anon/player/owner/admin with isolated staging accounts, propose reviewed rollback-safe fixes only where an actual bypass is proved. The inventory task **77.01** is covered; **77.02–77.11 remain open**. Do not infer production state from staging.
