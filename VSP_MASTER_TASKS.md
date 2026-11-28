# VSP Master Tasks Registry

**Branch (`VSP.App`):** `feat/vsp-recovery-gamification-ds` (Draft PR #47)  
**Staging Project:** `vtwgqyxglevcsxwdmhop` (Production `mktqkddbcddrxjxabdua` strictly protected)  
**Last Updated:** 2026-11-27

> **Strict Verification States:**  
> `Fixed` (code/asset changed) • `Tested` (automated/DB tests pass) • `Visually Verified` (inspected in live UI/image) • `Approved` (all acceptance criteria met) • `Blocked` (external/env blocker)

| Task ID | Priority | Description | Root Cause | Affected Platforms | Affected Files | Status | Evidence |
|---|---|---|---|---|---|---|---|
| `SHIELD-01` | P0 | Remove green from `shield_immortal.png` & remove `shield_platinum.png` | `shield_immortal.png` had bright green emerald/glow; `shield_platinum.png` remained on disk | Flutter, Assets | `assets/images/shields/shield_immortal.png`, `test/architecture_guardrails_test.dart` | **Tested + Visually Verified** | `shield_immortal.png` regenerated in royal gold/obsidian (visually inspected), `shield_platinum.png` deleted; guardrail test passes |
| `DS-01` | P0 | Single Source of Truth Design Tokens & Cross-Repo Sync | `success` and `focusRing` still aliased `voltGreen` (`#9FDF02`) | Flutter, Website, Admin | `vsp_design_tokens.dart`, `design-tokens.json`, `generated_tokens.ts`, `generated_tokens.json` | **Tested** | `sync_design_tokens.mjs --check` & `test_token_propagation.mjs` PASS; `58/58` Flutter tests, `54/54` Admin tests, `tsc --noEmit` PASS |
| `DS-02` | P0 | Mandatory Brand Rule (`#9FDF02` CTA only) & Shared Card Cleanup | `team_card_hero.dart`, `team_gamification_panel.dart`, `stadium_card.dart`, `public_match_card.dart`, `teams_ranking_tab.dart` had green borders/glows | Flutter | `team_card_hero.dart`, `team_gamification_panel.dart`, `stadium_card.dart`, `public_match_card.dart`, `teams_ranking_tab.dart` | **Tested** (Live device visual check **Blocked**) | `flutter analyze` (`0` issues) + `58/58` tests pass; live Android UI inspection pending emulator launch |
| `SEC-01` | P0 | Close `vsp_assert_admin_or_service_role` bypass & entitlement RLS | `CURRENT_USER` inside `SECURITY DEFINER` trusted `postgres` owner for `authenticated` callers; `season_reward_entitlements_read_all` exposed payout columns | Supabase Staging | `20261127100000`, `20261127120000` | **Tested (Staging)** | `security_negative_tests.sql` verified `authenticated` NULL-sub, `player`, and `owner` all rejected (`42501`) |
| `GAME-01` | P0 | 2-Month Competitive Rewards, Budget Cap (`2,100 EGP`), Canonical Ranking & E2E | Missing full budget check (`1500 cash + 5 free hours`), FK/table typos, and unverified E2E lifecycle | Flutter, Website, Admin, Staging DB | `20261127080000`, `20261127100000`, `20261127110000`, `20261127120000`, `teams_ranking_tab.dart` | **Tested (Staging)** | `e2e_staging_test.sql` & `security_negative_tests.sql` pass (exit `0`) on `vsp-staging` |
| `FIN-01` | P0 | Paymob Sandbox Live Checkout/Refund & New-Cash Block | Sandbox credentials not configured in local `env.json` | Flutter, Paymob | `paymob_fee_calculation_test.dart`, `paymob_zero_trust_security_test.dart` | **Tested (Unit)** / **Blocked (Sandbox)** | Unit/security tests pass; live Paymob Sandbox API test **Blocked** without sandbox credentials |
| `BUILD-01` | P0 | Local Staging APK (`vsp-demo-staging-release.apk`) & Emulator Install | Existing APK predates latest `0068cf2f` UI fixes; `Pixel_9` emulator not booted | Android | `build/app/outputs/flutter-apk/vsp-demo-staging-release.apk` | **Blocked (Time/Env)** | Existing 38.5MB APK built earlier; fresh APK rebuild & `Pixel_9` install queued as next step |
| `IOS-01` | P2 | iOS Build & Physical Device Validation | Windows host lacks macOS / Xcode | iOS | — | **Blocked (Env)** | Windows host (`Not Tested`) |
