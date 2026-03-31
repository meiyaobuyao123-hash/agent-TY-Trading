import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../../../shared/models/market.dart';
import '../data/markets_repository.dart';

final marketsRepositoryProvider = Provider<MarketsRepository>((ref) {
  return MarketsRepository(ref.watch(dioProvider));
});

/// Provides list of all tracked markets.
final marketsProvider = FutureProvider<List<Market>>((ref) async {
  final repo = ref.watch(marketsRepositoryProvider);
  return repo.fetchMarkets();
});
