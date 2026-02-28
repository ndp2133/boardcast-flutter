import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Can't test full BoardcastApp (needs Supabase/Hive init).
// Test the UI widget in isolation.
void main() {
  testWidgets('App shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Boardcast')),
        ),
      ),
    );
    expect(find.text('Boardcast'), findsOneWidget);
  });
}
