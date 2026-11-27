# VSP Handoff Document

**Current Branch (`VSP.App`):** `feat/vsp-recovery-gamification-ds` (Draft PR #47)  
**Sibling Repos:** `vsp_website` & `vsp_admin_panel` (`feat/unify-commission-paymob-fees`)  
**Staging Project:** `https://vtwgqyxglevcsxwdmhop.supabase.co` (`vsp-staging`)  
**Production Project:** `mktqkddbcddrxjxabdua` (DO NOT TOUCH)

## 1. Completed in Current Pass
- Replaced `assets/images/shields/shield_immortal.png` with royal-gold/obsidian 3D emblem (visually inspected, zero green) and deleted legacy `assets/images/shields/shield_platinum.png`.
- Removed `#9FDF02` from `VSPDSSemanticColors.success` (`blue500`) and `focusRing` (`zinc400`), synced `design-tokens.json` across all 3 repos (`sync_design_tokens.mjs --check` & `test_token_propagation.mjs` PASS), and added automated guardrails in `test/architecture_guardrails_test.dart`.
- Removed remaining green borders/glows from `team_card_hero.dart`, `team_gamification_panel.dart`, `stadium_card.dart`, and `public_match_card.dart`.
- Verified `flutter analyze --no-pub` (0 issues), `58/58` Flutter tests, `54/54` Admin tests, and `vsp_website` `tsc --noEmit`.

## 2. Exact Next Steps (For Next Run / Device QA)
1. Boot `Pixel_9` emulator (`flutter emulators --launch Pixel_9`) and build & install fresh `vsp-demo-staging-release.apk` connected to `vsp-staging`.
2. Visually verify all 6 shields, 3 ranking zones, and RTL/LTR layouts on the running Android emulator, capturing Before/After screenshots.
3. Run live Paymob Sandbox checkout/refund tests once sandbox credentials are provided.
4. Obtain legal sign-off on cash competition terms before any `Production` release.
