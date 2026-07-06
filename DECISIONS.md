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
23. Google Apps Script receiver code can be stored in repo documentation for manual copy/deploy; deployed Web App URLs may be configured only when the user explicitly approves them, and credentials must not be committed.
24. Google Sheet sync writes a backup/reporting copy of Local Data Vault snapshots and must not replace SQLite as the source of truth.
25. For Point 48, the user-approved deployed Apps Script Web App `/exec` URL is configured in Flutter sync settings; no Google API key, OAuth secret, or service-account file is used.
26. Point 49: Google Sheet sync failures must never block local data writes; failures are recorded in `sync_queue.json` and retried from the latest Local Data Vault snapshot.
27. Point 49: Google Sheet sync retry should use the latest Local Data Vault snapshot and clear pending state only after confirmed success.
28. Point 55: Google Sheet sync is optional and must be OFF by default on fresh installs.
29. Point 55: Users must explicitly enable Google Sheet sync and configure their own Apps Script Web App `/exec` endpoint from Settings.
30. Point 55: Disabling Google Sheet sync must stop all Google Sheet network sends without stopping SQLite, Local Data Vault export, AI vault reads, or PhonePe PDF import.
31. Point 55 supersedes automatic endpoint configuration from Point 48: the existing developer endpoint may remain as a dev-only reference but must never be selected or enabled automatically for APK users.
32. Point 56: Google Sheet sync must have only one active network sender path: Local Data Vault -> `GoogleSheetSyncService` -> Google Sheet. Legacy per-transaction `SheetsService` calls may remain only as no-op compatibility calls.
33. Point 56 follow-up / 55 minimal config: For the current developer build, the Apps Script Web App `/exec` endpoint is configured in `SyncSettingsService` and consumed only by the single vault-based Google Sheet sync path.
34. Point 55 resume: Settings may save a custom endpoint, but the effective endpoint is resolved only through `SyncSettingsService`; OFF continues to block Google Sheet network sync.
