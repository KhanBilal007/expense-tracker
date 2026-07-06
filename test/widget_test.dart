import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('Expense app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ExpenseApp(
        isDark: false,
        isHindi: false,
        recurringProcessed: [],
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
