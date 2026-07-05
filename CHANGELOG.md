# Changelog

## 2026-07-05

- Point 46: Improved AI vault account-name typo matching with staged fuzzy scoring and confidence-based clarification.
- Point 46: Connected AI finance answers to Local Data Vault JSON records with fuzzy account matching and vault-based calculations.
- Point 44 Verification: Added Local Data Vault debug logs for folder path, JSON file existence, and record counts after export.
- Point 44: Added Local Data Vault service, JSON exports, safe auto-refresh hooks, metadata, and future Google Sheet sync queue structure.
- Point 40: Refined AI follow-up memory with date-range context, clearer current-balance wording, and required account clarification wording.
- Point 43: Cancelled Dictate Mode and confirmed no mic UI, speech dependency, Android microphone permission, or voice input service remains.
- Point 40: Verified AI follow-up memory and relative date support for the requested balance follow-up flow; no app code change needed.
- Point 40: Added AI Assistant follow-up context and relative date support for balance and spent questions.
- Point 40: Refined AI Agent natural-language finance handling for monthly spending, account expenses, account income, account-name cleanup, and per-account balance totals.
- Point 39: Increased the AI Agent Option 2 icon size slightly in the AI screen header and Home bottom navigation.
- Point 40: Improved AI Agent intent detection, app-help answers, clarification handling, account summaries, and read-only transaction search.
- Point 39: Registered and wired the selected Option 2 AI Agent icon for the AI screen and bottom navigation AI item.
- Points 22 + 23 + 24: Added read-only backend finance query helpers and updated AI Assistant to answer supported balance, expense, spent, and money-added questions from real app data.
- Points 21 + 25: Added a basic local AI Assistant screen and replaced the bottom navigation Add Expense item with AI while preserving the Expense feature.
- Points 37 + 38: Expanded shared account summary so Home and Reports use the same backend source for money added, spent, today expenses, this month expenses, and current balance.
- Point 37: Added shared account summary calculation and updated Home/Reports to use the same backend source for matching account balances/totals.
- Point 35: Updated all visible money displays to whole rupees only using shared `formatMoneyWhole(...)`; stored values and calculations remain unchanged.
- Point 35: Removed forced trailing `.00` from visible money displays while preserving real decimal values.
- Points 18 + 19 + 20: Added Reports reset choice for `Reset by Date` or `Reset by Amount`, preserving amount reset and adding date-based balance recalculation without deleting transactions.
- Point 33: Removed the `View All` action from the Home Accounts section while keeping account cards and selection logic intact.
- Point 31: Fixed remaining Add Account lifecycle crash risk by waiting for dialog teardown before refreshing the Accounts list.
- Point 31: Verified Accounts Edit Cancel uses dialog context, does not refresh on Cancel, and matches the safe dialog lifecycle pattern.
- Points 31 + 32: Fixed Accounts screen dialog lifecycle risk and account row layout so names no longer wrap vertically.
- Points 15 + 16 + 17: Added persisted Home account selection for maximum 2 displayed accounts, with first-2 fallback and a compact chooser on Home.
- Points 12 + 13 + 30: Updated Transactions Sync to auto-import new PhonePe transactions directly, skip duplicates, show a simple result message, refresh All Transactions after import, and use `Uncategorized` for unclear imported categories.
- Updated All Transactions display so whole-number amounts omit `.00`, transaction titles use saved descriptions, and missing descriptions show `Undescribed`.
- Increased All Transactions amount number font size and constrained long amount display to avoid overflow.
- Fixed first account creation crash by making add/edit account dialogs close with their dialog context and refresh only after the dialog completes.
- Updated shared project tracking files for the account dialog lifecycle fix.
- Created shared project tracking files: `PROJECT_STATUS.md`, `THREAD_REPORTS.md`, `DECISIONS.md`, `TODO.md`, and `CHANGELOG.md`.
- Recorded current project baseline, confirmed decisions, and pending TODO items.
- No UI redesign, database logic, account balance calculations, or unrelated navigation changes were made.
