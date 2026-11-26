# VSP — App Store & Google Play Compliance Handover

- **Last Updated:** 2026-11-27
- **Active Branch:** `feat/unify-commission-paymob-fees`
- **Previous Commit:** `238c31c6` (`vsp_application`)
- **Staging Supabase Ref:** `vtwgqyxglevcsxwdmhop` (`vsp-staging`)

## Completed Fixes
1. **iOS Minimum Deployment Target & Privacy Manifest (A):**
   - Updated `IPHONEOS_DEPLOYMENT_TARGET` from `12.0` to `13.0` in `ios/Runner.xcodeproj/project.pbxproj`.
   - Added `ios/Podfile` (`platform :ios, '13.0'`, `use_frameworks!`).
   - Added `ios/Runner/PrivacyInfo.xcprivacy` with Required Reason APIs (`UserDefaults` `CA92.1`, `FileTimestamp` `C617.1`, `SystemBootTime` `35F9.1`, `DiskSpace` `E174.1`) and `NSPrivacyTracking = false`.
   - Updated stale `vsp.app` comment in `ios/Runner/Info.plist` to `vspapp.online`.
2. **Android Permissions & Store Compliance (B):**
   - Added `android:maxSdkVersion="32"` to `READ_EXTERNAL_STORAGE` and removed broad `READ_MEDIA_IMAGES` from `android/app/src/main/AndroidManifest.xml` (using Android Photo Picker via `image_picker`).
3. **Account Deletion for Social Login Owners (C):**
   - Updated `lib/features/owner/widgets/account/owner_delete_account_card.dart` so owners registered via Google/Apple (no email password) confirm with typed confirmation (`حذف` / `DELETE`) instead of being blocked by a non-existent password prompt.
4. **User Blocking & UGC Moderation (D):**
   - Added `lib/core/repositories/block_repository.dart` backed by Supabase `user_blocks` (with existing RLS policies).
   - Added `showBlockUserDialog` in `lib/features/player/widgets/chat/chat_dialogs.dart` and wired it into `lib/features/player/screens/chat_screen.dart`.
   - Added `lib/features/player/screens/profile_subscreens/blocked_users_screen.dart` for viewing and unblocking users.
5. **Age Policy Unification 18+ (E):**
   - Unified `lib/features/player/screens/terms_and_privacy_screen.dart`, `lib/shared/dialogs/vsp_terms_and_privacy_modal.dart`, and `vsp_website/src/locales/{ar,en}.ts` to `18+` matching `SignupValidationService.isAtLeast18`.

## Remaining / External / Manual Store Items
- **macOS / Xcode 26 + iOS 26 SDK Build (`Not Tested`):** Current environment is Windows; `pod install` and `flutter build ipa` must be run on macOS with Xcode 26+ (required by Apple starting April 28, 2026).
- **iOS Bundle Identifier (`com.example.vspApplication` -> `app.vsp.sports`):** `ios/Runner.xcodeproj/project.pbxproj` and `ios/Runner/GoogleService-Info.plist` currently share `com.example.vspApplication`. Must register `app.vsp.sports` in Apple Developer Portal & Firebase Console, download the matching `GoogleService-Info.plist`, and update `PRODUCT_BUNDLE_IDENTIFIER` before App Store submission.
- **Android AAB 16 KB Page-Size Verification:** Run `flutter build appbundle --release` with release keystore (`key.properties`) and inspect `.so` ELF alignment inside the `.aab`.

## Next Step
- Wire `BlockedUsersScreen` in `ProfileScreen`, run `flutter analyze`, `flutter test`, and `flutter build appbundle` / `apk`, and commit cleanly on `feat/unify-commission-paymob-fees`.
