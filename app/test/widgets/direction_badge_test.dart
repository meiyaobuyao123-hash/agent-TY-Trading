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
    testWidgets('renders 看涨 for up direction', (tester) async {
      await tester.pumpWidget(buildTestWidget('up'));

      expect(find.text('看涨'), findsOneWidget);
    });

    testWidgets('renders 看跌 for down direction', (tester) async {
      await tester.pumpWidget(buildTestWidget('down'));

      expect(find.text('看跌'), findsOneWidget);
    });

    testWidgets('renders 观望 for flat direction', (tester) async {
      await tester.pumpWidget(buildTestWidget('flat'));

      expect(find.text('观望'), findsOneWidget);
    });

    testWidgets('unknown direction renders as 观望', (tester) async {
      await tester.pumpWidget(buildTestWidget('unknown'));

      expect(find.text('观望'), findsOneWidget);
    });
  });
}
