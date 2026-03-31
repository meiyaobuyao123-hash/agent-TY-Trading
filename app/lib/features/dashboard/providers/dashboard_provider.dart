import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../../../shared/models/judgment.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioProvider));
});

/// Provides the latest judgments for the dashboard.
final latestJudgmentsProvider = FutureProvider<List<Judgment>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchLatestJudgments();
});
