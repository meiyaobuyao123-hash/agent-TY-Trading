/// An AI judgment about a market's direction.
class ModelVote {
  final String modelName;
  final String direction;
  final double confidence;
  final double? rationalPrice;
  final String reasoning;

  const ModelVote({
    required this.modelName,
    required this.direction,
    required this.confidence,
    this.rationalPrice,
    required this.reasoning,
  });

  factory ModelVote.fromJson(Map<String, dynamic> json) {
    return ModelVote(
      modelName: json['model_name'] as String,
      direction: json['direction'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      rationalPrice: (json['rational_price'] as num?)?.toDouble(),
      reasoning: json['reasoning'] as String,
    );
  }
}

/// Market regime information.
class MarketRegime {
  final String regime;
  final String description;
  final String color;

  const MarketRegime({
    required this.regime,
    required this.description,
    required this.color,
  });

  factory MarketRegime.fromJson(Map<String, dynamic> json) {
    return MarketRegime(
      regime: json['regime'] as String? ?? '震荡',
      description: json['description'] as String? ?? '',
      color: json['color'] as String? ?? '#6b7280',
    );
  }
}

/// A single bias flag detected in an AI judgment.
class BiasFlag {
  final String type;
  final String label;
  final String detail;
  final String severity;
  final String? intervention;

  const BiasFlag({
    required this.type,
    required this.label,
    required this.detail,
    required this.severity,
    this.intervention,
  });

  factory BiasFlag.fromJson(Map<String, dynamic> json) {
    return BiasFlag(
      type: json['type'] as String? ?? 'unknown',
      label: json['label'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
      intervention: json['intervention'] as String?,
    );
  }

  /// Whether an active bias intervention was applied (confidence adjusted).
  bool get hasIntervention => intervention != null && intervention!.isNotEmpty;
}

/// An AI judgment record.
class Judgment {
  final String id;
  final String marketId;
  final String? symbol;
  final String direction;
  final String confidence;
  final double confidenceScore;
  final double? rationalPrice;
  final double? deviationPct;
  final double? deviationSignificance;
  final String? reasoning;
  final List<ModelVote>? modelVotes;
  final double? qualityScore;
  final double? upProbability;
  final double? downProbability;
  final double? flatProbability;
  final List<BiasFlag>? biasFlags;
  final bool isLowConfidence;
  final MarketRegime? regime;
  final int horizonHours;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final bool isSettled;
  final bool? isCorrect;
  final bool isExpired;

  const Judgment({
    required this.id,
    required this.marketId,
    this.symbol,
    required this.direction,
    required this.confidence,
    required this.confidenceScore,
    this.rationalPrice,
    this.deviationPct,
    this.deviationSignificance,
    this.reasoning,
    this.modelVotes,
    this.qualityScore,
    this.upProbability,
    this.downProbability,
    this.flatProbability,
    this.biasFlags,
    this.isLowConfidence = false,
    this.regime,
    required this.horizonHours,
    this.expiresAt,
    required this.createdAt,
    required this.isSettled,
    this.isCorrect,
    this.isExpired = false,
  });

  factory Judgment.fromJson(Map<String, dynamic> json) {
    List<ModelVote>? votes;
    if (json['model_votes'] != null) {
      votes = (json['model_votes'] as List)
          .map((v) => ModelVote.fromJson(v as Map<String, dynamic>))
          .toList();
    }

    List<BiasFlag>? biasFlags;
    if (json['bias_flags'] != null) {
      biasFlags = (json['bias_flags'] as List)
          .map((f) => BiasFlag.fromJson(f as Map<String, dynamic>))
          .toList();
    }

    MarketRegime? regime;
    if (json['regime'] != null) {
      regime = MarketRegime.fromJson(json['regime'] as Map<String, dynamic>);
    }

    return Judgment(
      id: json['id'] as String,
      marketId: json['market_id'] as String,
      symbol: json['symbol'] as String?,
      direction: json['direction'] as String,
      confidence: json['confidence'] as String,
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      rationalPrice: (json['rational_price'] as num?)?.toDouble(),
      deviationPct: (json['deviation_pct'] as num?)?.toDouble(),
      deviationSignificance: (json['deviation_significance'] as num?)?.toDouble(),
      reasoning: json['reasoning'] as String?,
      modelVotes: votes,
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
      upProbability: (json['up_probability'] as num?)?.toDouble(),
      downProbability: (json['down_probability'] as num?)?.toDouble(),
      flatProbability: (json['flat_probability'] as num?)?.toDouble(),
      biasFlags: biasFlags,
      isLowConfidence: json['is_low_confidence'] as bool? ?? false,
      regime: regime,
      horizonHours: json['horizon_hours'] as int? ?? 4,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSettled: json['is_settled'] as bool? ?? false,
      isCorrect: json['is_correct'] as bool?,
      isExpired: json['is_expired'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Judgment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
