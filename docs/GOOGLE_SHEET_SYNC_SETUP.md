# Google Sheet Sync Setup

This document explains how to connect the Expense Tracker Local Data Vault export to a Google Sheet through a Google Apps Script Web App receiver.

## Architecture

- SQLite remains the source of truth.
- Local Data Vault remains the local readable mirror.
- Google Sheet is a backup/reporting copy only.
- AI Agent continues reading Local Data Vault, not Google Sheet.
- Flutter should not contain API keys, OAuth secrets, or service-account JSON.
- No API key in Flutter.
- No service account JSON in Flutter.
- No secrets committed.

## Required Google Sheet Tabs

The Apps Script creates or updates these tabs:

- Accounts
- Transactions
- Expenses
- MoneyAdded
- Transfers
- Summaries
- Metadata
- SyncLog

## Files

- Receiver script: `docs/google_apps_script_expense_tracker_sync.js`
- Flutter endpoint setting added later: `google_sheet_sync_endpoint`
- Current Flutter config service: `lib/services/sync_settings_service.dart`

## Google Sheet Setup Steps

1. Create a new Google Sheet.
2. Open `Extensions > Apps Script`.
3. Delete the default starter code.
4. Paste the full contents of `docs/google_apps_script_expense_tracker_sync.js`.
5. Save the Apps Script project.
6. Run `setupExpenseTrackerSheet` once from Apps Script.
7. Approve the spreadsheet permissions requested by Google.
8. Return to the spreadsheet and confirm all required tabs exist.

## Web App Deployment Steps

1. In Apps Script, click `Deploy > New deployment`.
2. Select deployment type `Web app`.
3. Set `Execute as` to `Me`.
4. Set access according to your intended use.
   - For direct Flutter POST sync without Google sign-in, use an access option that allows the app request to reach the Web App.
   - Keep the Web App URL private.
5. Click `Deploy`.
6. Copy the Web App URL.

## Where Flutter Web App URL Will Be Added Later

The Flutter app already has a configurable placeholder key:

```text
google_sheet_sync_endpoint
```

The endpoint should be stored through `SyncSettingsService` later. Do not hardcode the deployed Web App URL into source code, and do not commit credentials.

If no endpoint is configured, the app should log:

```text
GOOGLE_SHEET_SYNC_SKIPPED=no_endpoint_configured
```

## Test Payload Example

Use this sample body to test the Web App receiver from Apps Script or an API client:

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-07-06T10:00:00.000",
  "accounts": [
    {
      "id": 1,
      "name": "Cash",
      "currentBalance": 1200,
      "homeOrder": 0,
      "createdDate": null
    }
  ],
  "transactions": [
    {
      "id": 10,
      "account_id": 1,
      "account_name": "Cash",
      "category_id": 2,
      "category_name": "Food",
      "amount": 250,
      "type": "expense",
      "description": "Lunch",
      "date": "2026-07-06T09:30:00.000",
      "balance_after": 950,
      "is_recurring": 0,
      "source": "manual",
      "transaction_id": "",
      "dedupe_key": "manual-10"
    }
  ],
  "expenses": [
    {
      "id": 10,
      "account_id": 1,
      "account_name": "Cash",
      "category_id": 2,
      "category_name": "Food",
      "amount": 250,
      "type": "expense",
      "description": "Lunch",
      "date": "2026-07-06T09:30:00.000",
      "source": "manual",
      "transaction_id": "",
      "dedupe_key": "manual-10"
    }
  ],
  "moneyAdded": [],
  "transfers": [],
  "summaries": {
    "totals": {
      "accounts": 1,
      "transactions": 1
    }
  },
  "metadata": {
    "schemaVersion": 1,
    "lastExportAt": "2026-07-06T10:00:00.000",
    "source": "expense_tracker_local_data_vault"
  }
}
```

Expected response:

```json
{
  "ok": true,
  "status": "success",
  "receivedAt": "2026-07-06T10:00:00.000Z",
  "counts": {
    "accounts": 1,
    "transactions": 1,
    "expenses": 1,
    "moneyAdded": 0,
    "transfers": 0
  }
}
```

## Manual Verification Checklist

1. Run `setupExpenseTrackerSheet` in Apps Script.
2. Confirm the required tabs are created.
3. Deploy the Apps Script as a Web App.
4. Send the test payload to the Web App URL.
5. Confirm each tab receives the expected rows.
6. Confirm `SyncLog` records a success entry.
7. Send malformed JSON and confirm `SyncLog` records a failed entry.
8. Confirm no API key, service-account JSON, OAuth secret, or private token is committed.
9. Add the Web App URL to Flutter configuration later through the planned endpoint setting.
10. Trigger a Local Data Vault export from the app and confirm the Google Sheet receives the backup/reporting copy.

## Notes

- The script replaces tab data with the latest Local Data Vault snapshot.
- `SyncLog` is appended on each success or failure.
- Keep the Web App URL private. If it is exposed, create a new deployment URL and replace the configured endpoint.
- Do not use Google Sheet as the app database.
