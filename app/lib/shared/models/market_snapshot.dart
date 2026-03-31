/// A point-in-time snapshot of market data.
class MarketSnapshot {
  final String id;
  final double? price;
  final double? volume;
  final double? changePct;
  final DateTime capturedAt;

  const MarketSnapshot({
    required this.id,
    this.price,
    this.volume,
    this.changePct,
    required this.capturedAt,
  });

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) {
    return MarketSnapshot(
      id: json['id'] as String,
      price: (json['price'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
      changePct: (json['change_pct'] as num?)?.toDouble(),
      capturedAt: DateTime.parse(json['captured_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketSnapshot &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
