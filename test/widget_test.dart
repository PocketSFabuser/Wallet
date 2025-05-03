import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/main.dart';
import 'package:my_wallet/models.dart';
import 'package:my_wallet/stats_page.dart';

void main() {
  testWidgets('App starts and shows balance', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const MyApp());

    // Verify that initial balance is shown
    expect(find.text('0.00 BYN'), findsOneWidget);
  });

  testWidgets('Stats page shows with transactions', (WidgetTester tester) async {
    // Create test transactions
    final testTransactions = [
      Transaction(
          type: 'expense',
          amount: 100,
          date: DateTime.now(),
          description: 'Test',
          currency: 'BYN',
          category: ExpenseCategory.shopping),
    ];

    // Build stats page
    await tester.pumpWidget(MaterialApp(
      home: StatsPage(transactions: testTransactions),
    ));

    // Verify stats page shows
    expect(find.text('Статистика расходов'), findsOneWidget);
  });
}