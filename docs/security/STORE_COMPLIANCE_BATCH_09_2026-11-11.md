# Batch 09 — iOS build foundation, 2026-11-11

P1 confirmed build/configuration blockers: iOS Podfile absent; Runner bundle identifier still com.example.vspApplication while Firebase configuration identifies app.vsp.sports; deployment target 12.0 below locked Firebase Analytics 11.6.0's iOS 13.0 requirement; CocoaPods base-config includes missing.

Implemented: Flutter 3.32.8 official Swift Podfile template with iOS13, proper bundle/test identifiers, framework minimum13, CocoaPods includes and IDFA-free Analytics pod selection. Existing Analytics podspec was checked: global FirebaseAnalyticsWithoutAdIdSupport selects Firebase/AnalyticsWithoutAdIdSupport. Info.plist explicitly disables IDFA and ad-personalization signals. No ATT prompt, fabricated privacy disclosure or feature removal added.

CI now selects installed Xcode26.3 explicitly on macos-15 (its default remains16.4), checks iPhone SDK >=26, builds an unsigned release device application, and inspects its actual identity/platform/SDK/minimum OS/Mach-O plus SDK privacy manifest inventory. Eight local gate tests pass. This is not a completed iOS build until the new CI succeeds. SDK manifest inventory does not prove complete required-reason declarations or App Privacy disclosures.

Official sources checked 2026-11-11:
- [Apple SDK minimum requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a): effective April28,2026, Xcode26+/iOS26+ SDK for submissions.
- [Flutter iOS release](https://docs.flutter.dev/deployment/ios).
- [Pinned Flutter Podfile template](https://github.com/flutter/flutter/blob/3.32.8/packages/flutter_tools/templates/cocoapods/Podfile-ios-swift).
- [Pinned Firebase Analytics podspec](https://github.com/firebase/flutterfire/blob/firebase_analytics-v11.6.0/packages/firebase_analytics/firebase_analytics/ios/firebase_analytics.podspec).
- [GitHub macos15 installed toolchains](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md).
- [Apple privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

Unresolved: signed archive/export, Apple team/provisioning/App Store Connect, real device login/APNs, iOS OAuth client ID/redirect validation and full manifest/disclosure review. Existing Flutter version is preserved for the first real build; no untested SDK upgrade claimed. Core ledger remains81/620,539 pending.

Prior batch07 fully green at source5f249862e10733b9b3d22de64cfeccb2d6103a4a: Flutter CI42966012794 (1142 pass/10 skip;54 focused), native SQL42966012816 (6 suites,7 mutants,18 Python tests, inverse/forward restoration), Android42966012802 (2 smoke, compiled APK permissions and6 gate tests), checkout42966012902 (39 Deno tests). These do not prove the newly changed iOS package.
