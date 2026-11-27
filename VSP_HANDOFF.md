# VSP Handoff Document

**Current Branch:** `feat/vsp-recovery-gamification-ds` (Draft PR #47 in `VSP.App`, branched from `feat/unify-commission-paymob-fees` @ `dcc88af9`)  
**Staging Project:** `https://vtwgqyxglevcsxwdmhop.supabase.co` (`vsp-staging`)  
**Production Project:** `mktqkddbcddrxjxabdua` (DO NOT TOUCH)

## 1. Completed & Verified
- Cross-repo Design System V2 (`vsp_design_tokens.dart` + `design-tokens.json` + `scripts/sync_design_tokens.mjs` + `scripts/test_token_propagation.mjs`).
- Brand Rule Enforcement: `#9FDF02` reserved for CTAs; decorative green borders/glows removed from `select_role_screen.dart`, `booking_success_screen.dart`, `teams_ranking_tab.dart`, `vsp_shield_badge.dart`, and `VSPDSColors.tierImmortal`.
- Shield System Alignment: `TeamShieldTier` (`silver -> gold -> diamond -> elite -> legendary -> immortal`), 6 PNGs under `assets/images/shields/`, and full-emblem `VspShieldBadge` (no `ClipOval` / glow).
- 3 Ranking Zones & VSP Season Rewards (`VspSeasonRewards` + `TeamsRankingTab`):
  - Ranks 1–5: Cash Rewards Zone (`500 / 350 / 250 / 220 / 180 EGP`, `1,500 EGP` pool)
  - Ranks 6–10: Free Booking Zone (Free 1h voucher, max `180 EGP`)
  - Ranks 11+: Competition Zone with next realistic target gap to Top 10 / Top 5
- `vsp-staging` populated with Aswan season dataset (`1,000` players, `25` owners, `40` stadiums, `100` teams, `114` bookings with `75` paid financial snapshots backfilled, `50` `open_join`, `30` public challenges, `4` Strongest Team events, `6` Free-Hour awards, `70` notifications, `25` invites, `16` conversations, `12` payouts).
- Local staging APK built: `build/app/outputs/flutter-apk/vsp-demo-staging-release.apk` (`38.5 MB`).

## 2. Blocked (External Dependencies)
- Applying `supabase/migrations/20261127000000_fix_staging_booking_triggers.sql` and `supabase/migrations/20261127010000_competitive_seasons_cash_rewards.sql` remotely to `vsp-staging` (`SUPABASE_MANAGEMENT_KEY` in `env.json` returns `401 Unauthorized`).
- iOS validation & physical Android device testing (Windows host without macOS/Xcode).

## 3. Verification Commands
- Flutter: `flutter analyze --no-pub` and `flutter test`
- Token Propagation: `node scripts/test_token_propagation.mjs`
- Website: `cd ../vsp_website && npm run typecheck && npm test && npm run build`
- Admin: `cd ../vsp_admin_panel && npm test && npm run build`
