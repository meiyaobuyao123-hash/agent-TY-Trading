import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../../../shared/models/judgment.dart';
import '../../../shared/models/market.dart';
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
