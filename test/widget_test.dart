import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const BoardcastApp());
    expect(find.text('Boardcast — Phase 0 complete'), findsOneWidget);
  });
}
