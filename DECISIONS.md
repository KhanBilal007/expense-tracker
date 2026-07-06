# Decisions

## Confirmed Decisions

1. Do not change or disturb unrelated parts of the app while editing.
2. Keep Expense feature, but replace only the bottom navigation Expense tab with AI tab.
3. Home page should show maximum 2 selected accounts.
4. PDF imported transactions with unclear classification/category should be added as Uncategorized.
5. Reset by Date should recalculate balance using transactions up to the selected date.
6. PDF import should auto-sync valid transactions and should not ask which transactions to add.
7. Money amounts should be displayed as whole rupees only.
8. Decimal values should not be shown anywhere in the app UI.
9. Whole-rupee money display is display-only unless the user later approves rounding stored values.
10. Internal technical values may still use decimals when needed and must not be changed for display-only decisions.
11. Dedupe keys using `amount.toStringAsFixed(2)`, imported transaction IDs/dedupe IDs, date timestamps such as `.000`, parser values, and internal matching values should remain unchanged because they are not shown to the user and may be needed for duplicate detection or date handling.
12. SQLite/app database remains the source of truth.
13. Local Data Vault is a synchronized readable mirror, not the primary database.
14. AI Agent and future Google Sheet sync should read from or sync through the Local Data Vault only through safe read/export services.
15. Google Sheet API integration is not part of the Local Data Vault setup until explicitly approved later.
16. AI finance answers should use Local Data Vault JSON records as the main readable data source where possible.
17. AI must treat Local Data Vault access as read-only and must not create, edit, delete, reset, transfer, sync, or modify data.
18. For Google Sheet sync, SQLite remains the source of truth and Local Data Vault remains the local readable mirror.
19. Google Sheet is a backup/reporting copy and should not become the app's primary data source.
20. Google Sheet sync must use a configurable endpoint and must not hardcode credentials, API keys, OAuth secrets, or service-account JSON.
21. If no Google Sheet endpoint is configured, sync must skip safely without crashing the app.
22. AI Agent continues reading Local Data Vault and should not read Google Sheet directly.
