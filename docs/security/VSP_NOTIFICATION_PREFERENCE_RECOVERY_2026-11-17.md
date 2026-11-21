# VSP notification settings — account-switch and storage-error recovery

Date: 2026-11-17. Branch `uxlp-44-implementation`.

## Source issue
Switches were already stored per-account, but after changing accounts the old toggle fields stayed in memory until the asynchronous `SharedPreferences` read completed. If loading failed, the screen exited loading state and showed old/default choices as though they had been verified for the newly signed-in account.

## Fix
- Reset all 10 toggle fields synchronously when the identity changes.
- If loading persisted settings fails, show the shared localized error state with an actual retry action rather than showing unverified switches.
- Retry re-reads preferences only for the current active account, preserving the existing `mounted` and user-ID checks.
- Existing persistence fix now changes a visible switch only after its local save succeeds.

## Tests and limits
Isolated architecture tests assert account-scope reset, storage failure, reload and save-before-UI contracts; Flutter CI must verify them on the current commit. These source fixes are local to notification settings and do not prove server-side FCM suppression or hosted two-user RLS access.

49.04 ACCEPTED narrowly after [focused Flutter CI SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44144855159) on `bc293e3`. Other broad notification/consent and cross-account tasks remain open, no schema or production writes. 633 total / 274 accepted / 359 open after CI proof.
