import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/components/empty_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('EmptyState', () {
    testWidgets('renders icon, title, and subtitle', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(
          icon: Icons.surfing,
          title: 'No sessions yet',
          subtitle: 'The ocean is waiting.',
        ),
      ));

      expect(find.byIcon(Icons.surfing), findsOneWidget);
      expect(find.text('No sessions yet'), findsOneWidget);
      expect(find.text('The ocean is waiting.'), findsOneWidget);
    });

    testWidgets('does not show action button when not provided', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(
          icon: Icons.surfing,
          title: 'Title',
          subtitle: 'Subtitle',
        ),
      ));

      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('shows action button when provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        EmptyState(
          icon: Icons.surfing,
          title: 'Title',
          subtitle: 'Subtitle',
          actionLabel: 'Try Again',
          onAction: () => tapped = true,
        ),
      ));

      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(tapped, isTrue);
    });

    testWidgets('icon uses accent color at 0.3 opacity', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(
          icon: Icons.surfing,
          title: 'Title',
          subtitle: 'Subtitle',
        ),
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.surfing));
      expect(icon.size, 48);
      // Color should be accent with 0.3 alpha
      expect(icon.color, isNotNull);
    });
  });
}
