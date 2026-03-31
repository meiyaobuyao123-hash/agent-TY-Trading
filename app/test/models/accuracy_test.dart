import 'package:flutter_test/flutter_test.dart';
import 'package:ty_trading/shared/models/accuracy.dart';

void main() {
  group('AccuracyStat', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'acc-1',
        'market_type': 'crypto',
        'period': 'all',
        'total_judgments': 100,
        'correct_judgments': 65,
        'accuracy_pct': 65.0,
        'calibration_err': 3.2,
        'high_conf_accuracy': 72.0,
        'medium_conf_accuracy': 60.0,
        'low_conf_accuracy': 45.0,
        'calculated_at': '2026-03-31T08:00:00',
      };

      final stat = AccuracyStat.fromJson(json);
      expect(stat.id, 'acc-1');
      expect(stat.marketType, 'crypto');
      expect(stat.period, 'all');
      expect(stat.totalJudgments, 100);
      expect(stat.correctJudgments, 65);
      expect(stat.accuracyPct, 65.0);
      expect(stat.calibrationErr, 3.2);
      expect(stat.highConfAccuracy, 72.0);
      expect(stat.mediumConfAccuracy, 60.0);
      expect(stat.lowConfAccuracy, 45.0);
    });

    test('fromJson handles null confidence breakdowns', () {
      final json = {
        'id': 'acc-2',
        'market_type': 'forex',
        'period': '7d',
        'total_judgments': 20,
        'correct_judgments': 12,
        'accuracy_pct': 60.0,
        'calibration_err': 5.0,
        'high_conf_accuracy': null,
        'medium_conf_accuracy': null,
        'low_conf_accuracy': null,
        'calculated_at': '2026-03-31T08:00:00',
      };

      final stat = AccuracyStat.fromJson(json);
      expect(stat.highConfAccuracy, isNull);
      expect(stat.mediumConfAccuracy, isNull);
      expect(stat.lowConfAccuracy, isNull);
    });
  });

  group('CalibrationPoint', () {
    test('fromJson parses correctly', () {
      final json = {
        'confidence_bucket': '70-80%',
        'predicted_pct': 75.0,
        'actual_pct': 72.0,
        'count': 25,
      };

      final point = CalibrationPoint.fromJson(json);
      expect(point.confidenceBucket, '70-80%');
      expect(point.predictedPct, 75.0);
      expect(point.actualPct, 72.0);
      expect(point.count, 25);
    });
  });
}
