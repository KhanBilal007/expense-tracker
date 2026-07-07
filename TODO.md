# TODO

1. [x] Fix first account creation crash. Fixed 2026-07-05.
2. [x] Increase All Transactions amount digit font size. Fixed 2026-07-05.
2a. [x] Remove `.00` from whole-number All Transactions amounts and show transaction descriptions instead of `Money Added`. Fixed 2026-07-05.
3. [x] Replace bottom nav Add Expense tab with AI tab while preserving Expense feature elsewhere. Fixed 2026-07-05.
4. [x] Add AI tab screen. Fixed 2026-07-05.
5. [x] Add backend deterministic query service for AI tab. Fixed 2026-07-05.
6. [x] Add home account selection preference, maximum 2 accounts. Fixed 2026-07-05.
7. [x] Auto-sync PDF transactions without review screen. Fixed 2026-07-05.
8. [x] Mark unclear PDF categories as Uncategorized. Fixed 2026-07-05.
9. [x] Add reset account choice: Reset by Date or Reset by Amount. Fixed 2026-07-05.
10. [x] Implement Reset by Date using recalculation up to selected date. Fixed 2026-07-05.
11. Run full bug audit after each major change.
12. [x] Fix Accounts screen lifecycle crash risk and account row vertical text layout. Fixed 2026-07-05.
13. [x] Verify Accounts Edit Cancel closes safely without using parent context. Fixed 2026-07-05.
14. [x] Fix remaining Add Account lifecycle crash on save. Fixed 2026-07-05.
15. [x] Remove Home Accounts `View All` option. Fixed 2026-07-05.
16. [x] Remove trailing `.00` from visible money/amount figures. Fixed 2026-07-05.
17. [x] Show all visible money/amount figures as whole rupees only. Fixed 2026-07-05.
18. [x] Make Home and Reports use shared account summary calculation. Fixed 2026-07-05.
19. [x] Make Home expenses, today, and this month use shared account summary calculation. Fixed 2026-07-05.
20. [x] Record decimal-display decision as UI-only while preserving internal decimal technical values. Fixed 2026-07-05.
21. [x] Use selected Option 2 AI Agent icon for AI tab/screen branding. Fixed 2026-07-05.
22. [x] Increase AI Agent intelligence for natural-language finance, transaction, and app-help questions. Fixed 2026-07-05.
23. [x] Increase AI Agent Option 2 icon size slightly. Fixed 2026-07-05.
24. [x] Refine AI Agent finance phrasing and per-account sum-balance answers. Fixed 2026-07-05.
25. [x] Add AI Assistant follow-up context and relative date support. Fixed 2026-07-05.
26. [x] Verify AI Assistant follow-up memory for `what it was 20 day ago`. Fixed 2026-07-05.
27. [x] Cancel/remove Dictate Mode from AI Assistant. Completed 2026-07-05; no Dictate Mode code remained.
28. [x] Refine AI Assistant follow-up memory with date range and clearer clarification handling. Fixed 2026-07-05.
29. [x] Create Local Data Vault JSON mirror for future AI and Google Sheet sync. Fixed 2026-07-05.
30. [x] Add Local Data Vault verification debug log. Fixed 2026-07-05.
31. [x] Connect AI Agent finance answers to Local Data Vault records. Fixed 2026-07-05.
32. [x] Improve AI vault account-name spelling mistake handling. Fixed 2026-07-05.
33. [x] Prepare Google Sheet auto-sync from Local Data Vault. Fixed 2026-07-06.
34. [x] Create Google Apps Script receiver code and Google Sheet sync setup documentation. Fixed 2026-07-06.
35. [x] Point 48: Configure deployed Google Apps Script Web App endpoint for Google Sheet auto-sync. Fixed 2026-07-06.
36. [x] Point 49: Add Google Sheet sync status and retry safety. Fixed 2026-07-06.
37. [x] Point 50: Fix AI latest/recent transaction questions from Local Data Vault. Fixed 2026-07-06.
38. [x] Point 50: Build complete AI Transaction Query Brain for Local Data Vault records. Fixed 2026-07-06.
39. [x] Point 48 / 49 Follow-up: Fix Google Sheet sync HTTP 302 redirect failure. Fixed 2026-07-06.
40. [x] Point 48 / 49 Follow-up: Use GET, not POST, for Apps Script 302/303 redirect target. Fixed 2026-07-06.
41. [x] Point 50 Analyze Fix: Resolve `MyApp` widget test error and unnecessary transaction non-null assertion warning. Fixed 2026-07-06.
42. [x] Point 49: Finish Google Sheet sync status and retry safety with HTTP status tracking. Fixed 2026-07-06.
43. [x] Point 51: Clean safe Flutter analyze warnings without changing behavior. Fixed 2026-07-06.
44. [x] Point 39: Fix AI bottom navigation icon size and label visibility without card-style redesign. Fixed 2026-07-06.
45. [x] Point 39: Reduce bottom navigation height and prevent Recent Transactions overlap. Fixed 2026-07-06.
46. [x] Point 39: Try compact 54px bottom navigation sizing. Fixed 2026-07-06.
47. [x] Point 52: Reuse Transactions PhonePe PDF sync from the Home bottom navigation Sync button. Fixed 2026-07-06.
48. [x] Point 11: Complete full static project bug audit and create `BUG_AUDIT_REPORT.md`. Fixed 2026-07-06.
49. Make Add Expense, Add Money, SMS import, and recurring balance/transaction writes atomic.
50. [x] Consolidate legacy `SheetsService` with active Local Data Vault Google Sheet sync configuration. Fixed 2026-07-06.
51. Wire `retryPendingGoogleSheetSync()` to a safe automatic retry trigger.
52. Serialize Local Data Vault exports and sync status writes.
53. Apply dialog-local context and post-close refresh patterns to Categories, Budgets, Rules, and Recurring.
54. Define and fix recurring month-end and missed-period behavior.
55. Add automated tests for finance calculations, reset, parser/dedupe, vault, Google sync, and AI queries.
56. Review Android SMS/storage permissions and production release signing.
57. [x] Point 53: Make Home background white and readable in light mode while preserving dark mode. Fixed 2026-07-06.
58. [x] Point 55: Make Google Sheet sync optional, OFF by default, and controlled from Settings. Fixed 2026-07-06.
59. [x] Point 56: Consolidate Google Sheet sync into one Local Data Vault based path. Fixed 2026-07-06.
60. [x] Point 56 Follow-up / 55 Minimal Config: Restore vault-based Google Sheet endpoint configuration. Fixed 2026-07-06.
61. [x] Point 55 Resume: Finish Settings sync status/config behavior without disturbing Point 56. Fixed 2026-07-06.
62. [x] Point 53: Prepare Home dark-mode code/detail package for Claude light-theme conversion. Fixed 2026-07-06.
63. [x] Point 53: Apply Home base light-mode theme fix without optional 3D styling. Fixed 2026-07-06.
64. [x] Point 57: Remove visible Language option from Settings. Fixed 2026-07-07.
65. [x] Point 59 Correction: Use First-time Opening Balance formula for first PhonePe Sync. Fixed 2026-07-07.
66. [x] Point 59 Follow-up Bug Fix: Fix first-time PhonePe balance dialog controller lifecycle crash. Fixed 2026-07-07.
67. [x] Point 59 Local Vault Export Bug Fix: Make Local Data Vault JSON writes safe after PhonePe import. Fixed 2026-07-07.
68. [x] Point 59 Final Bug Fix: Prevent balance-dialog lifecycle crash and double Google Sheet sync after PhonePe import. Fixed 2026-07-07.
69. [x] Point 60 Add Provision: Add Settings controls to set/reset Total Money Added baseline without changing balances or transactions. Fixed 2026-07-07.
70. [x] Point 59 Final Simplest: Use a default PhonePe account and skip old statement transactions during first setup. Fixed 2026-07-07.
71. [x] Point 61: Exclude sync-managed PhonePe account from manual Add Money/Add Expense account selection. Fixed 2026-07-07.
72. [x] Point 62: Make Home summary totals use all accounts while keeping visible account cards unchanged. Fixed 2026-07-07.
