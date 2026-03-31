import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ty_trading/shared/widgets/confidence_bar.dart';

void main() {
  Widget buildTestWidget(double confidence) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: ConfidenceBar(confidence: confidence),
        ),
      ),
    );
  }

  group('ConfidenceBar', () {
    testWidgets('renders percentage text for 85%', (tester) async {
      await tester.pumpWidget(buildTestWidget(0.85));

      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Confidence'), findsOneWidget);
    });

    testWidgets('renders percentage text for 0%', (tester) async {
      await tester.pumpWidget(buildTestWidget(0.0));

      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('renders percentage text for 100%', (tester) async {
      await tester.pumpWidget(buildTestWidget(1.0));

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('clamps values above 1.0', (tester) async {
      await tester.pumpWidget(buildTestWidget(1.5));

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('clamps values below 0.0', (tester) async {
      await tester.pumpWidget(buildTestWidget(-0.5));

      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('renders FractionallySizedBox for fill', (tester) async {
      await tester.pumpWidget(buildTestWidget(0.5));

      final fractionBoxes = find.byType(FractionallySizedBox);
      expect(fractionBoxes, findsOneWidget);

      final FractionallySizedBox box =
          tester.widget(fractionBoxes);
      expect(box.widthFactor, 0.5);
    });
  });
}
