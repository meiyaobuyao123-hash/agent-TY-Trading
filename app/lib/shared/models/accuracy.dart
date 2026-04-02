/// Accuracy statistics for a market type and period.
class AccuracyStat {
  final String id;
  final String marketType;
  final String period;
  final int totalJudgments;
  final int correctJudgments;
  final double accuracyPct;
  final double calibrationErr;
  final double? highConfAccuracy;
  final double? mediumConfAccuracy;
  final double? lowConfAccuracy;
  final DateTime calculatedAt;

  const AccuracyStat({
    required this.id,
    required this.marketType,
    required this.period,
    required this.totalJudgments,
    required this.correctJudgments,
    required this.accuracyPct,
    required this.calibrationErr,
    this.highConfAccuracy,
    this.mediumConfAccuracy,
    this.lowConfAccuracy,
    required this.calculatedAt,
  });

  factory AccuracyStat.fromJson(Map<String, dynamic> json) {
    return AccuracyStat(
      id: json['id'] as String,
      marketType: json['market_type'] as String,
      period: json['period'] as String,
      totalJudgments: json['total_judgments'] as int,
      correctJudgments: json['correct_judgments'] as int,
      accuracyPct: (json['accuracy_pct'] as num).toDouble(),
      calibrationErr: (json['calibration_err'] as num).toDouble(),
      highConfAccuracy: (json['high_conf_accuracy'] as num?)?.toDouble(),
      mediumConfAccuracy: (json['medium_conf_accuracy'] as num?)?.toDouble(),
      lowConfAccuracy: (json['low_conf_accuracy'] as num?)?.toDouble(),
      calculatedAt: DateTime.parse(json['calculated_at'] as String),
    );
  }
}

/// A single accuracy history data point for trend chart.
class AccuracyHistoryItem {
  final DateTime calculatedAt;
  final double accuracyPct;
  final int totalJudgments;
  final int correctJudgments;

  const AccuracyHistoryItem({
    required this.calculatedAt,
    required this.accuracyPct,
    required this.totalJudgments,
    required this.correctJudgments,
  });

  factory AccuracyHistoryItem.fromJson(Map<String, dynamic> json) {
    return AccuracyHistoryItem(
      calculatedAt: DateTime.parse(json['calculated_at'] as String),
      accuracyPct: (json['accuracy_pct'] as num).toDouble(),
      totalJudgments: json['total_judgments'] as int,
      correctJudgments: json['correct_judgments'] as int,
    );
  }
}

/// A single point on the calibration curve.
class CalibrationPoint {
  final String confidenceBucket;
  final double predictedPct;
  final double actualPct;
  final int count;

  const CalibrationPoint({
    required this.confidenceBucket,
    required this.predictedPct,
    required this.actualPct,
    required this.count,
  });

  factory CalibrationPoint.fromJson(Map<String, dynamic> json) {
    return CalibrationPoint(
      confidenceBucket: json['confidence_bucket'] as String,
      predictedPct: (json['predicted_pct'] as num).toDouble(),
      actualPct: (json['actual_pct'] as num).toDouble(),
      count: json['count'] as int,
    );
  }
}
