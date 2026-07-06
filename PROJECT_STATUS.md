# Project Status

Date: 2026-07-05

## Project

Expense Tracker Flutter app.

## Current Baseline

- Flutter app with local database.
- Home screen is in `lib/screens/home_screen.dart`.
- Current home account display uses first two accounts from `_accounts.take(2)`.
- Current bottom nav is inside `home_screen.dart` and has Home, Add Expense, Sync.
- Current PDF import flow in `transactions_screen.dart` opens `ImportReviewScreen`.
- Current duplicate handling uses `dedupe_key` in `database_helper.dart`.
- Current reports/reset logic is in `reports_screen.dart` and `database_helper.dart`.
- Account creation flow is in `accounts_screen.dart`.

## Current Status

- Point 51 applied: Flutter analyze cleanup replaced deprecated safe UI APIs and reduced lint warnings without feature changes.
- Point 49 completed: Google Sheet sync status now includes final HTTP status and retry reports success or pending state.
- Point 50 Analyze Fix applied: widget test now uses `ExpenseApp`, and the unnecessary transaction description non-null assertion was removed.
- Point 48 / 49 redirect follow-up applied: Google Sheet sync now POSTs only to Apps Script `/exec`, then follows 302/303 redirect targets with GET.
- Point 50 expanded: AI Agent now has a structured Transaction Query Brain for recent, date, account, category/keyword, expense, money-added, and combined transaction filters.
- Point 50 applied: AI Agent now answers recent/latest transaction questions from Local Data Vault instead of treating them as keyword searches.
- Point 49 applied: Google Sheet sync status now records payload counts, success state, and pending retry safety.
- Point 48 applied: Google Apps Script Web App `/exec` endpoint is configured in Flutter sync settings for real Google Sheet auto-sync.
- Point 47 documented: Google Apps Script receiver code and Google Sheet setup guide were added for Local Data Vault sync.
- Point 45 applied: Google Sheet sync service now reads Local Data Vault and safely posts to a configurable Apps Script endpoint.
- Point 46 refined: AI vault account matching now handles spelling mistakes with staged fuzzy confidence rules.
- Point 46 applied: AI Agent finance answers now read from Local Data Vault through a vault reader service.
- Point 44 verification applied: Local Data Vault export now prints path, file existence, and record count debug logs.
- Point 44 applied: Local Data Vault service and safe SQLite-to-JSON mirror export added for future AI/Google Sheet sync.
- Point 40 refined: AI Assistant follow-up memory now keeps last date range and clearer account clarification wording.
- Point 43 completed: Dictate Mode was cancelled and confirmed absent from AI Assistant code, dependencies, permissions, and services.
- Point 40 confirmed: AI follow-up memory and relative date handling are present for balance follow-ups like `what it was 20 day ago`.
- Point 40 refined: AI Assistant now remembers last finance context and answers relative-date follow-ups.
- Point 40 refined: AI Agent now handles more finance phrasing and shows per-account lines for balance-sum answers.
- Point 39 updated: AI Agent Option 2 icon size increased slightly in the AI screen header and Home bottom navigation.
- Point 40 applied: AI Agent now has broader deterministic intent detection, richer app-help answers, account summaries, and read-only transaction search.
- Point 39 applied: AI tab/screen now uses the selected Option 2 friendly robot icon asset path.
- Points 22 + 23 + 24 applied: AI Assistant now answers supported finance-data questions from read-only backend calculations.
- Points 21 + 25 applied: Bottom navigation now opens an AI tab instead of Add Expense, and a basic AI Assistant screen exists.
- Points 37 + 38 applied: Home and Reports now use shared account summary calculation for balance, money added, spent, today expenses, and this month expenses.
- Point 37 applied: Home and Reports now use shared account summary calculation from `database_helper.dart`.
- Point 35 updated: all visible money UI now displays whole rupees only, with no decimal digits.
- Point 35 applied: visible money amounts no longer show trailing `.00`.
- Points 18 + 19 + 20 applied: Reports reset now asks Date or Amount before applying reset.
- Point 33 applied: Home Accounts section no longer shows `View All`.
- Point 31 remaining Add Account crash fix applied: Add Account now waits for dialog teardown before refreshing the Accounts list.
- Point 31 verified: Accounts Edit Cancel now closes with dialog context and does not call `_load()`.
- Points 31 + 32 applied: Accounts screen dialog lifecycle risk and vertical account-name row layout issue fixed.
- Points 15 + 16 + 17 applied: Home can display a user-selected maximum of 2 accounts with persistence after restart.
- Points 12 + 13 + 30 applied: Transactions Sync now auto-imports PhonePe transactions without opening the manual review screen.
- All Transactions amount/title display update applied in `lib/screens/transactions_screen.dart`.
- All Transactions amount digit readability update applied in `lib/screens/transactions_screen.dart`.
- First account creation crash fix applied in `lib/screens/accounts_screen.dart`.
- Shared project tracking files have been created.
- This baseline capture is documentation/status setup only.
- No UI design, account balance logic, or unrelated navigation was changed.

## Latest AI Finance Query Update

- Added deterministic read-only account lookup and finance query helpers in `lib/db/database_helper.dart`.
- Updated `lib/screens/ai_screen.dart` to answer supported finance questions locally from app data.
- Supported finance answers include current balance, selected-account balance sum, balance on date, today expense, this month expense, spent from account, and money added to account.
- AI responses use whole rupees only through the shared money formatter.
- AI remains read-only and does not create, update, delete, reset, or sync transactions.
- External AI/API integration and backend write actions were not added.

## Latest AI Icon Update

- Registered `assets/icons/ai_agent_option_2_icon.png` in `pubspec.yaml`.
- Added the selected Option 2 AI Agent icon to the AI Assistant app bar.
- Updated the Home bottom navigation AI item to use the same asset at compact icon size.
- Increased the AI Assistant header icon from 28px to 40px.
- Increased the Home bottom navigation AI image icon from 26px to 30px.
- Kept fallback robot icons so layout remains stable if the asset cannot load.
- User still needs to place `ai_agent_option_2_icon_1024.png` as `assets/icons/ai_agent_option_2_icon.png` before running Flutter.

## Latest AI Intelligence Update

- Improved AI question understanding for balances, account balance sums, balance-on-date, today expense, this month expense, spent, money added, account summaries, transactions, and app help.
- Added follow-up context for last finance account, intent, and date.
- Follow-up context now also keeps the last finance date range when available.
- Current balance answers now say `balance today is ...`, making later relative-date follow-ups clearer.
- Multiple account matches now ask `Which account do you mean?` and show matching options.
- Added relative date handling for today, yesterday, N days ago, last week, this month, last month, and `on 5 July` style follow-ups.
- Balance follow-ups now use `getAccountBalanceOnDate(...)` for historical values.
- Spent follow-ups for day/month/week periods use read-only range expense queries.
- Refined phrasing support for `monthly spending`, `expenses from account`, `income in account`, and account names that include the word `account`.
- Sum-balance answers now show each matched account balance and the final total.
- Added explicit local intent detection in `lib/screens/ai_screen.dart`.
- Added read-only `searchTransactionsForAi(...)` in `lib/db/database_helper.dart`.
- Reused existing backend summary methods for financial answers.
- Added clarification responses for missing or ambiguous account names and missing dates.
- Expanded app-help responses for accounts, expenses, add money, transfers, PDF sync, reports, reset by date, reset by amount, Home account selection, and AI usage.
- AI remains read-only and does not create, edit, delete, reset, sync, or call external AI/API services.

## Latest Dictate Mode Cleanup

- Confirmed no microphone button is present in `lib/screens/ai_screen.dart`.
- Confirmed no Dictate/listening UI or speech-to-text code is present.
- Confirmed `speech_to_text` is not present in `pubspec.yaml`.
- Confirmed Android `RECORD_AUDIO` permission is not present.
- Confirmed no `lib/services/voice_input_service.dart` file exists.
- Typed AI input and Send button remain the only AI input path.
- No app code changes were required for this cleanup pass.

## Latest Local Data Vault Update

- Added `lib/services/local_data_vault_service.dart`.
- Added `path_provider` for app-local document storage.
- Local vault folder: app documents directory plus `expense_tracker_data`.
- Vault JSON files: `accounts.json`, `transactions.json`, `expenses.json`, `money_added.json`, `transfers.json`, `summaries.json`, `metadata.json`, and `sync_queue.json`.
- SQLite remains the source of truth; Local Data Vault is a synchronized readable mirror.
- Added manual export method `exportAllDataToLocalVault()` in `database_helper.dart`.
- Added safe export scheduling after the database first opens.
- Added safe refresh hooks after account changes, transaction inserts, transaction account moves, transfers, reset/report-state changes, reset all data, and PhonePe imports.
- Vault export failures are caught and logged with `debugPrint` so app flows do not crash.
- After successful export, debug logs now print `LOCAL_DATA_VAULT_PATH`, file existence for key JSON files, and counts for accounts, transactions, expenses, and money added.
- Google Sheet API was not added.
- AI Agent was not rewritten, but vault read methods are available for future AI use.

## Latest AI Vault Integration Update

- Added `lib/services/ai_vault_reader_service.dart`.
- AI finance answers now use Local Data Vault JSON records through the vault reader service.
- AI reads vault accounts, transactions, expenses, money added, summaries, and metadata safely.
- Improved fuzzy account matching for exact, partial, token, initials, vowel-loose, and Levenshtein spelling-mistake account queries.
- Added confidence thresholds so clear best matches are used, close matches ask clarification, and low-confidence matches are rejected.
- Current balance, historical balance, expenses, money added, totals, and transaction search are calculated from vault data.
- AI screen no longer imports `DatabaseHelper` for finance answers.
- Missing or unreadable vault data returns a safe message instead of guessing.
- AI remains read-only and does not create, edit, delete, reset, transfer, sync, or modify data.
- Dictate Mode, mic UI, AI icon, Google Sheet API, and external AI/API integrations were not added.

## Latest Google Sheet Sync Update

- Point 49 completed retry/status safety with `lastHttpStatus`, `GOOGLE_SHEET_SYNC_RETRY_SUCCESS`, and `GOOGLE_SHEET_SYNC_RETRY_PENDING`.
- Point 49 added richer sync status tracking: `lastPayloadCounts` and `isLastSyncSuccessful`.
- Failed Google Sheet syncs now keep local vault data intact, preserve a pending retry count, and continue logging `GOOGLE_SHEET_SYNC_FAILED=<safe error>`.
- Added `retryPendingGoogleSheetSync()` for safe retry of the latest Local Data Vault snapshot when pending sync exists.
- Point 48 configured the deployed Google Apps Script Web App endpoint in `SyncSettingsService`.
- Endpoint validation now requires the configured URL to end with `/exec`.
- Google Sheet sync continues to send Local Data Vault payloads through `GoogleSheetSyncService`.
- Point 47 added repo documentation/script files for the Google Apps Script receiver and setup process.
- Receiver script writes Local Data Vault payloads into `Accounts`, `Transactions`, `Expenses`, `MoneyAdded`, `Transfers`, `Summaries`, `Metadata`, and `SyncLog` tabs.
- Setup guide records Google Sheet setup steps, Web App deployment steps, endpoint placement, test payload, and verification checklist.
- Added `lib/services/google_sheet_sync_service.dart`.
- Added `lib/services/sync_settings_service.dart`.
- Google Sheet sync reads Local Data Vault JSON files and prepares one payload for a future Google Apps Script Web App endpoint.
- Endpoint is configurable through `SyncSettingsService` and defaults to empty.
- If endpoint is empty, sync prints `GOOGLE_SHEET_SYNC_SKIPPED=no_endpoint_configured` and does not crash.
- Added sync payload fields: `schemaVersion`, `exportedAt`, `accounts`, `transactions`, `expenses`, `moneyAdded`, `transfers`, `summaries`, and `metadata`.
- Added planned tabs: Accounts, Transactions, Expenses, MoneyAdded, Transfers, Summaries, Metadata, and SyncLog.
- Added sync status in `sync_queue.json`: `lastAttemptAt`, `lastSuccessAt`, `pendingCount`, `lastError`, and `endpointConfigured`.
- Local Data Vault export now triggers safe Google Sheet sync after successful export.
- No Google credentials, API keys, OAuth secrets, service-account JSON, Google Sheet API package, or external AI/API was added.

## Latest AI Tab UI Update

- Added `lib/screens/ai_screen.dart`.
- Added `AppRoutes.ai` and registered it in the app route table.
- Replaced only the Home bottom navigation `Add Expense` tab with `AI`.
- Preserved the Expense feature and existing `AppRoutes.addExpense` route.
- Add Expense remains available outside bottom navigation, including existing Home quick actions.
- AI Assistant is read-only/local for now and answers simple app-help questions.
- Finance data answers show the placeholder: `Finance data answers will be available after backend query support is added.`
- Backend financial query logic was not added.

## Latest Accounts Screen Fix

- Add Account dialog now uses an explicit dialog builder block with local `dialogContext` for Cancel and Add closes.
- Add Account still inserts inside the Add button, closes with `Navigator.of(dialogContext).pop(true)`, and never calls `_load()` inside the button callback.
- After Add dialog returns `true`, Accounts waits for `WidgetsBinding.instance.endOfFrame`, checks `mounted`, then refreshes with `_load()`.
- Add Account controllers are disposed only after the dialog completes, in `finally`.
- Confirmed Edit Account Cancel uses `Navigator.of(dialogContext).pop(false)`.
- Confirmed Edit Account Save uses dialog context and refreshes only after `showDialog` returns `true`.
- Confirmed Add Account and Delete confirmation use dialog context for Cancel/close actions.
- Updated delete confirmation dialog to close with the dialog builder context.
- Add/edit account dialogs keep dialog-context close handling and check dialog context after async saves.
- Delete flow now checks `mounted` after async database delete before showing SnackBar or refreshing.
- Account list rows now use a controlled `Row` layout instead of `ListTile` trailing controls.
- Account names are constrained to one line with ellipsis to prevent vertical letter wrapping.
- Amount text remains visible with the existing green/red balance color behavior and scales down for long balances.
- Database logic, balance calculations, routes, and unrelated screens remain unchanged.

## Latest Home UI Update

- Removed only the `View All` text/action from the Home Accounts section.
- Kept account cards, selected Home account display, and `Choose` account selection logic unchanged.
- No backend/database changes were made.

## Latest Reports Reset Update

- Reset now first asks the user to choose `Reset by Date` or `Reset by Amount`.
- `Reset by Amount` preserves the existing behavior: user taps a transaction to use as the reset amount.
- `Reset by Date` asks for a date, previews the recalculated balance, asks for confirmation, then applies the reset.
- Date reset recalculates balance from inferred account opening balance plus account-affecting transactions up to the selected date.
- Expenses and transfers out reduce balance; income and transfers in increase balance.
- Old transactions are not deleted.
- Home, Accounts, Transactions, Sync, AI tab, and unrelated Reports UI remain unchanged.

## Latest Money Display Update

- Updated money display requirement from hiding only `.00` to showing whole rupees only.
- Confirmed whole-rupee formatting is a visible UI display rule only.
- Internal technical decimals remain allowed for dedupe keys, imported transaction IDs/dedupe IDs, timestamps, parser values, and matching values.
- Internal uses such as `amount.toStringAsFixed(2)` for duplicate detection should not be removed for this display-only decision.
- Added shared formatter `lib/utils/money_formatter.dart` with `formatMoneyWhole(num amount)`.
- Visible money values now round to whole rupees, so `₹560.50` displays as `₹561` and `₹560.75` displays as `₹561`.
- Updated visible amount placeholders from `0.00` to `0`.
- Replaced visible decimal money formatting with `formatMoneyWhole(...)`.
- Updated visible insufficient-balance SnackBar amounts to whole rupees.
- Whole-number money values now display like `₹560`, `₹1,200`, and `₹0`.
- Stored values, calculations, database logic, imported transaction values, dedupe-key formatting, labels, and UI layout remain unchanged.

## Latest Calculation Consistency Fix

- Added shared backend method `getAccountSummary(int accountId)`.
- Shared summary returns `availableFunds`, `totalMoneyAdded`, `spent`, `todayExpenses`, `thisMonthExpenses`, and `currentBalance`.
- Home now aggregates selected Home accounts using `getAccountSummary(...)`.
- Home account rows now show each selected account balance from the same summary source.
- Home `Today`, `Expenses`, `This Month`, `Total Money Added`, and `Current Balance` now use the shared summary source.
- Reports summary cards now use `getAccountSummary(...)` for account totals and spent.
- Total Money Added on Home now uses all income/add-money transactions for selected Home accounts, not only the current month.
- Expense/spent totals count expense transactions; transfer-out reduces balance without being counted as expense.
- Transfers into an account increase available funds.
- Stored transaction amounts, account data, PDF sync, and visible UI layouts remain unchanged.

## Latest Home Account Selection Update

- Added persisted Home account selection using `accounts.home_order`.
- Added `getHomeAccounts()` and `setHomeAccounts(List<int> accountIds)` helpers.
- Home loads selected accounts separately from the full account list.
- Home account card still shows maximum 2 accounts.
- If no Home selection exists, Home falls back to the first 2 accounts.
- Deleted selected accounts are ignored naturally because selection is stored on existing account rows.
- Added a compact `Choose` action beside the Accounts header to select up to 2 Home accounts.
- Account balances, expense/transfer logic, Transactions, Reports, PDF import, AI tab, and bottom navigation remain unchanged.

## Latest PhonePe Sync Update

- Transactions tab Sync now uses the existing Sync button and directly imports new PhonePe transactions.
- `ImportReviewScreen` is no longer opened from this Sync flow.
- Existing scanner, parser, dedupe-key filtering, and `insertPhonePeTransactions` database import path are preserved.
- Sync result is shown with a simple SnackBar summary for saved transactions and skipped duplicates.
- All Transactions refreshes after successful auto-import.
- Unclear imported categories are saved as `Uncategorized`; the category is created if missing.
- `ImportReviewScreen` file still exists and was not deleted.
- Home, Reports, Accounts, AI tab, bottom navigation, transaction calculations, and database schema remain unchanged.

## Latest Transactions Display Update

- Whole-number transaction amounts no longer show `.00` in the All Transactions list.
- Transaction titles now show the saved transaction description.
- Transactions with no saved description now show `Undescribed`.
- `Balance Reset` title handling remains unchanged.
- Transaction logic, database logic, calculations, amount sign/color handling, and account/date subtitles remain unchanged.

## Latest UI Update

- Increased only the transaction amount number font size in the All Transactions list.
- Kept labels, dates, descriptions, transaction logic, database logic, and calculations unchanged.
- Added a constrained scale-down wrapper around the amount text so long amounts do not overflow.

## Latest Fix

- Updated account add/edit dialog lifecycle handling.
- Dialogs now close using the dialog builder context.
- Account list refresh now runs only after the dialog closes successfully.
- Dialog text controllers are disposed in `finally` blocks after `showDialog` completes.
