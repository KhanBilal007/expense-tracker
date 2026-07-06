# Expense Tracker

A Flutter expense tracker with SQLite as the source of truth, whole-rupee UI,
account summaries, PhonePe statement import, Reports reset flows, a Local Data
Vault JSON mirror, Google Sheet backup sync, and a read-only local AI assistant.

## Project References

- Current state: `PROJECT_STATUS.md`
- Confirmed decisions: `DECISIONS.md`
- Work queue: `TODO.md`
- Change history: `CHANGELOG.md`
- Latest static audit: `BUG_AUDIT_REPORT.md`
- Google Sheet setup: `docs/GOOGLE_SHEET_SYNC_SETUP.md`

## Manual Verification

Run from the Flutter project directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

SQLite remains the source of truth. Local Data Vault and Google Sheet data are
mirrors for AI reads, backup, and reporting.
