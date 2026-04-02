import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../../../shared/models/judgment.dart';
import '../../../shared/models/market.dart';
import '../../../shared/models/market_snapshot.dart';
import '../data/market_detail_repository.dart';

final marketDetailRepositoryProvider =
    Provider<MarketDetailRepository>((ref) {
  return MarketDetailRepository(ref.watch(dioProvider));
});

/// Provides a single market detail by symbol.
final marketDetailProvider =
    FutureProvider.family<Market, String>((ref, symbol) async {
  final repo = ref.watch(marketDetailRepositoryProvider);
  return repo.fetchMarket(symbol);
});

/// Provides judgment history for a market symbol.
final marketJudgmentsProvider =
    FutureProvider.family<List<Judgment>, String>((ref, symbol) async {
  final repo = ref.watch(marketDetailRepositoryProvider);
  return repo.fetchJudgments(symbol);
});

/// Provides historical price snapshots for a market.
final marketSnapshotsProvider =
    FutureProvider.family<List<MarketSnapshot>, String>((ref, symbol) async {
  final repo = ref.watch(marketDetailRepositoryProvider);
  return repo.fetchSnapshots(symbol);
});

/// Provides related/correlated markets for a symbol.
final relatedMarketsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, symbol) async {
  final repo = ref.watch(marketDetailRepositoryProvider);
  return repo.fetchRelatedMarkets(symbol);
});
