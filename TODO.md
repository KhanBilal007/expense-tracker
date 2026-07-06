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
