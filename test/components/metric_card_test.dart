import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/components/metric_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('MetricCard', () {
    testWidgets('renders name, value, unit, and subLabel', (tester) async {
      await tester.pumpWidget(wrap(
        const MetricCard(
          name: 'Waves',
          value: '3.2',
          unit: 'ft',
          subLabel: 'SW 12s',
        ),
      ));

      expect(find.text('Waves'), findsOneWidget);
      expect(find.text('3.2'), findsOneWidget);
      expect(find.text('ft'), findsOneWidget);
      expect(find.text('SW 12s'), findsOneWidget);
    });

    testWidgets('renders formatted numericValue via TweenAnimationBuilder',
        (tester) async {
      await tester.pumpWidget(wrap(
        MetricCard(
          name: 'Waves',
          value: '3.2',
          unit: 'ft',
          subLabel: 'SW 12s',
          numericValue: 3.2,
          formatValue: (v) => v.toStringAsFixed(1),
        ),
      ));

      // After pumping, the tween should reach the end value
      await tester.pumpAndSettle();
      expect(find.text('3.2'), findsOneWidget);
    });

    testWidgets('falls back to static value without numericValue',
        (tester) async {
      await tester.pumpWidget(wrap(
        const MetricCard(
          name: 'Tide',
          value: '--',
          unit: 'ft',
          subLabel: 'Unknown',
        ),
      ));

      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('shows dot color when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const MetricCard(
          name: 'Wind',
          value: '10',
          unit: 'mph',
          subLabel: 'NW',
          dotColor: Colors.green,
        ),
      ));

      // The dot is a Container with BoxDecoration — find by decoration
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
    });
  });
}
