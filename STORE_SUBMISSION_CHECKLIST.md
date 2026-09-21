# VSP Store Submission Checklist

Last reviewed: 2026-09-21

## Implemented in code

- Android target SDK 36 / compile SDK 36.
- Release signing fails closed when production signing material is missing.
- Broad legacy Android storage/media permissions removed.
- Location is requested only after an explicit user action during signup.
- Minimum signup age enforced: Player 16+, Stadium Owner 21+.
- iOS PrivacyInfo.xcprivacy added and embedded.
- UGC report + block flow implemented.
- Supabase block enforcement prevents blocked users from chatting.
- Account deletion is server-side and no longer falls back to client-side partial deletion.
- Historical identity references are nulled where appropriate before account removal.
- Web account deletion request page: /delete-account.
- Copilot booking flow no longer assumes a missing date and asks for ambiguous 1–6 AM/PM times.
- vsp_copilot deployed as production version 49.
- CI includes a release AAB build gate.

## External submission tasks

### Google Play Console
- Complete App content declarations.
- Complete Data Safety and Data Deletion questions.
- Add the web account deletion resource:
  https://www.vspapp.online/delete-account
- Provide reviewer access/demo credentials if login is required.
- Confirm the final production signing certificate matches assetlinks.json.
- Review permissions and declared data collection against the final production build.

### Apple App Store Connect
- Set the final Apple Team ID + production bundle identifier in Xcode.
- Replace the AASA placeholder appID in the website:
  TEAMID.app.vsp.sports
- Confirm the final Apple privacy nutrition labels match actual collection and SDK behavior.
- Provide reviewer access/demo credentials and App Review notes.
- Confirm the final production signing/capabilities configuration.

### Supabase Dashboard
- Enable Auth leaked-password protection.
- Confirm production Storage objects are removed for deleted accounts where applicable; Storage deletion must use the Storage API.
- Review Security Advisor findings and retain SECURITY DEFINER only where required by the application's atomic/RLS architecture.

## Important release rule

Do not submit the iOS build until the real Apple Team ID and production bundle identifier are known. Do not replace the placeholder by guessing.
