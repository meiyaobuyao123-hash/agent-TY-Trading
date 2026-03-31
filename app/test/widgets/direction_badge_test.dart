import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ty_trading/shared/widgets/direction_badge.dart';

void main() {
  Widget buildTestWidget(String direction) {
    return MaterialApp(
      home: Scaffold(
        body: DirectionBadge(direction: direction),
      ),
    );
  }

  group('DirectionBadge', () {
    testWidgets('renders UP with green arrow', (tester) async {
      await tester.pumpWidget(buildTestWidget('up'));

      expect(find.text('UP'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('renders DOWN with red arrow', (tester) async {
      await tester.pumpWidget(buildTestWidget('down'));

      expect(find.text('DOWN'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('renders FLAT with dash', (tester) async {
      await tester.pumpWidget(buildTestWidget('flat'));

      expect(find.text('FLAT'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('unknown direction renders as FLAT', (tester) async {
      await tester.pumpWidget(buildTestWidget('unknown'));

      expect(find.text('FLAT'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });
}
