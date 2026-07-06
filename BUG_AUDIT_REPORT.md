# Bug Audit Report

Date: 2026-07-06
Point: 11
Method: Full static code and configuration inspection. No terminal or Flutter commands were run.

## Summary

The active application paths are present and internally connected: startup, Home,
Accounts, transaction entry, transfers, Transactions, shared PhonePe sync, Reports,
Local Data Vault, Google Sheet sync, and the read-only AI Agent.

Four small low-risk fixes were made during the audit. Larger findings were not changed
because they affect persistence, sync behavior, permissions, or multiple feature flows.
`flutter analyze`, tests, and runtime verification are still required from the user.

## Features Verified By Code Inspection

- App startup initializes Flutter, preferences, recurring processing, routes, and Home.
- Home reads account summaries from `DatabaseHelper.getAccountSummary(...)`.
- Home account selection remains limited to two persisted account choices.
- Accounts add/edit dialogs use dialog-local contexts and delayed list refresh.
- Add Expense and Add Money validate amount and account selection.
- Transfers validate accounts, balance, and use one SQLite transaction.
- Transactions loads filters, account changes, and the shared PhonePe sync service.
- Home Sync and Transactions Sync both call `PhonePeSyncService`.
- PhonePe sync scans Downloads, parses statements, filters dedupe keys, and auto-imports.
- PhonePe imports continue through `insertPhonePeTransactions(...)`, preserving vault export.
- Reports reads shared account summaries and supports Reset by Date and Reset by Amount.
- Reset by Date recalculates through `calculateAccountBalanceAtDate(...)` without deleting transactions.
- Visible money formatting uses whole-rupee formatting; internal dedupe decimals remain intact.
- Local Data Vault writes all expected JSON files through temporary files.
- Google Sheet sync has timeout, redirect handling, status persistence, and a retry method.
- AI reads Local Data Vault and contains no database write, external AI, mic, or speech path.
- Bottom navigation remains Home, AI, and Sync with the compact layout.
- Android manifest contains network, SMS, and storage permissions used by current services.
- The selected AI icon asset exists and is registered in `pubspec.yaml`.

## Possible Bugs Found

### High Priority

1. Add Expense, Add Money, foreground SMS import, background SMS import, and recurring
   processing update an account balance and insert its transaction in separate database
   operations. A failure between operations can leave balance and transaction history inconsistent.

2. `retryPendingGoogleSheetSync()` has no caller. Failed sync status is recorded, but
   automatic later retry is not currently wired to startup, resume, or a data-change hook.

3. Two Google Sheet integrations coexist. Settings and Add Expense/Add Money/Transfer use
   legacy `SheetsService` and preference key `sheets_script_url`; vault sync uses
   `GoogleSheetSyncService` and `google_sheet_sync_endpoint`. The Settings URL therefore does
   not configure the active vault sync, and per-row posts may duplicate or conflict with bulk sync.

4. SMS ingestion has no transaction ID or dedupe key. Foreground/background delivery or an
   app restart can potentially import the same SMS more than once. SMS listening also starts
   automatically during app startup.

### Medium Priority

5. Local Data Vault exports are launched with `unawaited(...)` after many database writes.
   Concurrent exports share the same `.tmp` paths and can race with each other or with AI reads
   and Google sync status writes.

6. Categories, Budgets, Rules, and Recurring dialogs still close with the parent screen context
   and refresh inside button callbacks. This resembles the lifecycle pattern previously fixed in
   Accounts and should be hardened in a dedicated dialog-safety point.

7. Recurring processing is not atomic and advances monthly dates with Dart overflow semantics.
   Dates such as the 29th, 30th, or 31st may skip into a later month. Only one occurrence is
   processed when several periods were missed.

8. Startup awaits recurring processing before `runApp` without a top-level recovery path.
   A database/plugin exception can prevent the first frame from appearing.

9. Settings says `Reset App Data` / `ALL data`, but the implementation clears transactions and
   transfers and zeroes balances while retaining accounts, categories, rules, budgets, and recurring items.

10. Android requests broad SMS and `MANAGE_EXTERNAL_STORAGE` permissions. These may be required
    by current features, but they need device-version and distribution-policy verification.

11. Release configuration currently signs with the debug key. This is acceptable for local
    testing but not for production distribution.

### Low Priority / Maintenance

12. `ImportReviewScreen` remains compiled but has no active caller after automatic import replaced it.
13. `models.dart` is not used by the active map-based persistence/UI paths.
14. The widget test is only a shallow smoke test; finance, parser, sync, reset, vault, and AI
    behavior have no automated regression coverage in the repository.

## Low-Risk Fixes Made

- Removed the unused transaction ID local from Add Money without changing insertion behavior.
- Removed an unused `ColorScheme` local from Rules.
- Replaced a redundant PhonePe transaction ID null assertion with a promoted local variable.
- Corrected the Transactions end-date filter to exclude midnight at the start of the next day.
- Replaced the default Flutter README with a project-specific overview and manual verification commands.
- Corrected stale current-baseline entries in `PROJECT_STATUS.md`.

## Risky Fixes Not Made

- No financial write methods were refactored into new SQLite transactions.
- No legacy Google Sheet integration or Settings field was removed or rewired.
- No automatic retry trigger was added.
- No SMS listener, permission, or parser behavior was changed.
- No vault write queue/lock was introduced.
- No secondary dialog lifecycle methods were rewritten.
- No recurring schedule calculation was changed.
- No release signing or Android permission was changed.
- No dormant file was deleted.

## Analyzer Issues Remaining

`flutter analyze` was not run because the task explicitly prohibits terminal commands.
Static inspection removed two likely unused-local reports and one redundant assertion candidate.
The actual remaining analyzer count is unknown until the user runs the analyzer.

Potential non-analyzer quality issues remain in long, densely formatted files. Large formatting
or refactoring changes were intentionally avoided.

## Manual Test Checklist

1. Launch after a clean install and after an existing database upgrade.
2. Create, edit, cancel, and delete Accounts operations.
3. Add Expense and Add Money; compare account balance and transaction history.
4. Transfer between two accounts and verify both transaction rows and balances.
5. Filter Transactions with an end date and verify next-day midnight is excluded.
6. Sync with no PhonePe PDF, a valid PDF, and the same PDF twice.
7. Confirm Home and Transactions refresh after PhonePe import.
8. Confirm Local Data Vault files and counts update after each write flow.
9. Disable internet, create data, inspect pending sync status, restore internet, and test retry.
10. Verify Google Sheet rows are not duplicated by legacy and vault sync paths.
11. Test Reset by Date and Reset by Amount for one account with income, expense, and transfers.
12. Compare Home and Reports totals for the same selected account.
13. Ask AI direct, fuzzy-account, follow-up date, and recent-transaction questions.
14. Test recurring items on month-end dates and after several missed periods.
15. Test Android SMS/storage permission denial and acceptance flows.
16. Check Home, AI, and Sync bottom navigation on small screens and increased font scale.

## Recommended Next Points

1. Make Add Expense, Add Money, SMS import, and recurring processing atomic database operations.
2. Consolidate the two Google Sheet integrations and make Settings configure the active endpoint.
3. Wire pending Google Sheet retry to a safe startup/resume or connectivity-aware trigger.
4. Serialize Local Data Vault exports and sync status writes.
5. Apply the safe dialog-context/result pattern to Categories, Budgets, Rules, and Recurring.
6. Define month-end recurring behavior and add catch-up limits.
7. Add unit/widget tests for calculations, reset, dedupe, parser, vault, sync, and AI queries.
8. Review Android permissions and configure production release signing.
