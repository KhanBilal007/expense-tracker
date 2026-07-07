# Bug Audit Report

Date: 2026-07-07

Point No: 11

## Summary

Full static project audit completed before APK sharing. The audit inspected the core Flutter app flows, PhonePe sync, Local Data Vault, Google Sheet sync, AI Agent vault reader path, Settings, permissions, and shared project docs.

No Flutter, build, test, analyze, git, delete, rename, or run commands were executed.

One high-severity APK-sharing privacy bug was fixed: Google Sheet sync no longer falls back to the developer/test Apps Script endpoint when the saved endpoint is empty. Google Sheet sync remains OFF by default and now requires an explicitly saved user endpoint before any Google network sync can run.

## Files Inspected

- `lib/main.dart`
- `lib/db/database_helper.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/accounts_screen.dart`
- `lib/screens/add_expense_screen.dart`
- `lib/screens/add_money_screen.dart`
- `lib/screens/transactions_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/ai_screen.dart`
- `lib/screens/reports_screen.dart`
- `lib/services/phonepe_sync_service.dart`
- `lib/services/phonepe_statement_parser.dart`
- `lib/services/downloads_scanner_service.dart`
- `lib/services/local_data_vault_service.dart`
- `lib/services/google_sheet_sync_service.dart`
- `lib/services/sync_settings_service.dart`
- `lib/services/sheets_service.dart`
- `lib/services/ai_vault_reader_service.dart`
- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`
- Shared project docs

## Features Verified By Code Inspection

- Fresh database initialization seeds and reuses a single default `PhonePe` account.
- Existing installs call `ensureDefaultPhonePeAccount()` from database open/setup paths.
- PhonePe Sync uses the default PhonePe account and does not ask the user to select an account.
- First PhonePe setup creates `First-time Opening Balance` only, marks setup complete, and does not import old statement transactions.
- Future PhonePe Sync filters statement transactions after `phonePeSyncStartAt`.
- PhonePe imported transactions still use dedupe keys before insert.
- Manual Add Money and Add Expense use `getManualEntryAccounts()`, which excludes PhonePe.
- If only PhonePe exists, manual Add Money/Add Expense show a friendly manual-account message instead of crashing.
- Home summary cards use all-account totals while visible account cards can still show selected/first-two accounts.
- Total Money Added display uses the Point 60 baseline logic.
- Local Data Vault exports the required JSON files and serializes exports.
- Google Sheet sync uses the Local Data Vault payload path through `GoogleSheetSyncService`.
- Legacy `SheetsService` is a compatibility no-op and does not send per-transaction network requests.
- Google Sheet sync respects the enabled/disabled setting before network sync.
- Apps Script 302/303 redirect handling is centralized in Google Sheet sync.
- AI Agent reads from Local Data Vault and remains read-only.
- Dictate Mode/mic code was not reintroduced.
- Settings no longer shows the visible Language option.
- Home light-mode base colors are theme-aware while preserving layout dimensions.

## Bugs Found

### High - Fixed

**Google Sheet endpoint fallback could leak APK user data to the developer/test Sheet.**

`SyncSettingsService.getGoogleSheetEndpoint()` returned the developer configured endpoint when no endpoint was saved. If a shared APK user enabled Google Sheet Sync without entering their own Apps Script URL, app data could sync to the developer Sheet.

Status: Fixed.

Fix: `getGoogleSheetEndpoint()` now returns only the saved valid endpoint. Empty or invalid saved endpoint returns an empty string, causing Google Sheet sync to skip with `GOOGLE_SHEET_SYNC_SKIPPED=no_endpoint_configured`.

Files changed:

- `lib/services/sync_settings_service.dart`
- `lib/screens/settings_screen.dart`

### Medium - Documented

**PhonePe transaction account-change action may allow moving sync-managed PhonePe records manually.**

The Transactions screen includes account-change behavior for transactions. This can conflict with the rule that PhonePe should be managed only by Sync. This was not changed during the audit because it affects transaction management behavior and needs a specific product decision.

Recommended next point: restrict account changes for PhonePe imported/opening-balance system records, or confirm that admin correction is allowed.

### Medium - Documented

**Existing reused PhonePe account with nonzero balance before first setup can produce confusing first setup totals.**

Point 59 intentionally creates a First-time Opening Balance equal to the entered current PhonePe balance and skips old statement imports. On fresh install this is correct. On an existing install where a pre-existing PhonePe/PhonePe Wallet account already has balance but no setup marker, adding the full entered balance could make the stored PhonePe balance exceed the entered balance.

This was not changed because it touches Point 59 balance behavior.

Recommended next point: decide whether first setup should require an empty PhonePe account or calculate an offset only for existing nonzero PhonePe accounts.

### Medium - Documented

**Android storage and SMS permissions are release-risk areas.**

The manifest includes broad storage/SMS permissions, including `MANAGE_EXTERNAL_STORAGE`, `READ_SMS`, and `RECEIVE_SMS`. These may be acceptable for side-loaded APK testing but can be blockers or privacy concerns for broader distribution.

Recommended next point: review permissions before public sharing or Play Store release.

### Low - Documented

**Hidden old Hindi preference can still affect locale.**

The visible Settings Language option was removed, but `main.dart` still reads the `hindi` preference. If an old install had Hindi enabled before the option was removed, the app may continue using Hindi with no visible Settings control to change it.

Recommended next point: either clear/deprecate the old `hindi` preference or restore a deliberate language setting later.

### Low - Documented

**Some secondary dialogs may still use older lifecycle patterns.**

Earlier high-risk account and PhonePe dialogs were fixed. Some less-used dialogs, especially recurring-related flows, should still be reviewed for dialog-local context and post-close refresh patterns.

Recommended next point: perform a dialog lifecycle cleanup pass on Categories, Budgets, Rules, and Recurring.

### Low - Documented

**Mojibake rupee symbols remain in some source strings.**

Several UI strings appear to contain incorrectly encoded rupee symbols in source. Whole-rupee formatting helpers cover many visible amount displays, but a text/encoding polish pass is still recommended before final release.

## Low-Risk Fixes Made

- Removed the developer/test Google Sheet endpoint fallback from runtime endpoint resolution.
- Updated the Settings empty-endpoint snackbar so it no longer says a configured endpoint will be used after clearing the field.

## Risky Fixes Not Made

- PhonePe transaction account-change restriction.
- Existing nonzero PhonePe account first-setup offset behavior.
- Android permission reduction.
- Hidden old Hindi preference cleanup.
- Recurring and secondary dialog lifecycle refactor.
- Broad rupee-symbol text cleanup.

These were documented instead of changed because each could affect app behavior or user data flows beyond this audit.

## Analyzer Issues Remaining

`flutter analyze` was not run because Flutter commands were explicitly disallowed for this audit. The user should run it manually before APK sharing.

Likely areas to watch:

- Unused compatibility constants or methods around Google Sheet sync settings.
- Any remaining deprecated Flutter APIs in less-used screens.
- Any stale test references after app class changes.

## Manual Test Checklist

1. Fresh install / clear app data.
2. Open app and confirm the `PhonePe` account exists once.
3. Confirm no duplicate `PhonePe` account appears after restart.
4. Tap Add Money and confirm PhonePe is not shown.
5. Tap Add Expense and confirm PhonePe is not shown.
6. With only PhonePe present, confirm Add Money/Add Expense show the friendly manual-account message.
7. Run first PhonePe Sync, enter a current balance, and confirm only `First-time Opening Balance` is created.
8. Confirm old PhonePe statement transactions are not imported during first setup.
9. Download a fresh statement after setup and confirm only new transactions after setup import.
10. Re-sync the same PDF and confirm no duplicate transactions or duplicate opening balance.
11. Confirm Home Total Money Added, Current Balance, Today, Expenses, and This Month use all accounts.
12. Confirm Google Sheet Sync is OFF by default on a fresh install.
13. With Google Sheet Sync OFF, perform a data change and confirm no Google sync network log appears except disabled/skip logs.
14. Enable Google Sheet Sync, enter a valid `/exec` endpoint, sync, and confirm SyncLog success.
15. Clear the endpoint while sync is ON and confirm sync skips with no endpoint configured.
16. Confirm Local Data Vault files exist after PhonePe Sync.
17. Ask AI for balance and recent transactions and confirm answers come from Local Data Vault.
18. Toggle light/dark mode and confirm Home remains readable.
19. Open Settings and confirm Language is not visible while Google Sheet Sync settings remain visible.
20. Run `flutter analyze` manually and review any remaining warnings.

## Recommended Next Points

- Restrict account changes for PhonePe imported/system transactions if user confirms PhonePe should be fully sync-managed.
- Decide nonzero existing PhonePe account behavior during first setup.
- Review Android SMS/storage permissions before APK sharing beyond trusted testers.
- Add automated tests for PhonePe setup/import, all-account Home totals, Point 60 Total Money Added baseline, vault export, and Google Sheet sync gating.
- Perform a secondary dialog lifecycle cleanup pass.
- Run a source text encoding polish pass for rupee symbols.

## APK Readiness Status

Status: Conditionally ready for trusted manual APK testing after user runs the manual checks.

The main APK-sharing privacy blocker found in this audit was fixed. No build or analyzer verification was run in this task, so APK sharing should wait until the user runs `flutter analyze`, `flutter test` if available, and an actual debug/release run on device.
