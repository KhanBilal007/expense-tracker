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
