import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avokaido_app/widgets/usage_analytics_dashboard.dart';

void main() {
  testWidgets('UsageAnalyticsDashboard displays correct texts', (
    WidgetTester tester,
  ) async {
    // Build the widget
    await tester.pumpWidget(MaterialApp(home: UsageAnalyticsDashboard()));

    // Check for AppBar title
    expect(find.text('Usage Analytics Dashboard'), findsOneWidget);

    // Check for body text
    expect(find.text('Cost Attribution Analytics Dashboard'), findsOneWidget);
  });
}
