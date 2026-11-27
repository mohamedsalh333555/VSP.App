# VSP Handoff Document

**Current Branch:** `feat/vsp-recovery-gamification-ds` (branched from `feat/unify-commission-paymob-fees` @ `dcc88af9`)  
**Staging Project:** `https://vtwgqyxglevcsxwdmhop.supabase.co` (`vsp-staging`)  
**Production Project:** `mktqkddbcddrxjxabdua` (DO NOT TOUCH)

## 1. Completed & Verified
- Cross-repo Design System V2 (`vsp_design_tokens.dart` + `design-tokens.json` + `scripts/sync_design_tokens.mjs` + `scripts/test_token_propagation.mjs`).
- `vsp-staging` populated with Aswan season dataset (`1,000` players, `25` owners, `40` stadiums, `100` teams with `Silver 22 / Gold 18 / Diamond 14 / Elite 10 / Legendary 6 / Immortal 4 / None 26`, `50` `open_join`, `30` public challenges, `4` Strongest Team events, `6` Free-Hour awards, `70` notifications, `25` invites, `16` conversations, `12` payouts).
- Local staging APK built: `build/app/outputs/flutter-apk/vsp-demo-staging-release.apk` (37.3MB).

## 2. In Progress (Current Turn)
- Updating `TeamShieldTier` (`silver -> gold -> diamond -> elite -> legendary -> immortal`) & generating missing 3D shield PNGs (`shield_silver.png`, `shield_diamond.png`, `shield_elite.png`, `shield_legendary.png`).
- Removing circular clipping & glow from `VspShieldBadge`.
- Removing remaining decorative `borderAccent` / green shield tint.
- Backfilling `gross_amount_charged`, `player_vsp_fee`, `owner_vsp_fee`, `total_vsp_commission`, `owner_net_amount` on seeded `vsp-staging` bookings.

## 3. Blocked (External Dependencies)
- Applying `supabase/migrations/20261127000000_fix_staging_booking_triggers.sql` to `vsp-staging` (`SUPABASE_MANAGEMENT_KEY` in `env.json` returns `401 Unauthorized`).
- iOS validation (Windows host without macOS/Xcode).

## 4. Verification Commands
- Flutter: `flutter analyze --no-pub && flutter test`
- Token Propagation: `node scripts/test_token_propagation.mjs`
- Website: `cd ../vsp_website && npm run typecheck && npm test && npm run build`
- Admin: `cd ../vsp_admin_panel && npm test && npm run build`
