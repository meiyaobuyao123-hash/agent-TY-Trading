import 'market_snapshot.dart';

/// A tracked financial market/asset.
class Market {
  final String id;
  final String symbol;
  final String name;
  final String marketType;
  final String source;
  final bool isActive;
  final DateTime createdAt;
  final MarketSnapshot? latestSnapshot;
  final int? dataAgeSeconds;
  final String? dataAgeLabel;

  const Market({
    required this.id,
    required this.symbol,
    required this.name,
    required this.marketType,
    required this.source,
    required this.isActive,
    required this.createdAt,
    this.latestSnapshot,
    this.dataAgeSeconds,
    this.dataAgeLabel,
  });

  factory Market.fromJson(Map<String, dynamic> json) {
    return Market(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      marketType: json['market_type'] as String,
      source: json['source'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      latestSnapshot: json['latest_snapshot'] != null
          ? MarketSnapshot.fromJson(
              json['latest_snapshot'] as Map<String, dynamic>)
          : null,
      dataAgeSeconds: json['data_age_seconds'] as int?,
      dataAgeLabel: json['data_age_label'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Market && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
