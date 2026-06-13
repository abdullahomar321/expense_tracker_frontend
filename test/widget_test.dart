// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/providers/splash_provider.dart';

void main() {
  testWidgets('Logo screen builds successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SplashProvider()..startTimer(),
        child: const Expensetracker(),
      ),
    );

    // Verify that our logo image asset is present.
    expect(find.byType(Image), findsOneWidget);

    // Consume the 3-second delayed timer so that no timers remain pending
    await tester.pump(const Duration(seconds: 3));
  });
}
