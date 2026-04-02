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

/// Provides system overview stats for the AI evolution card.
final overviewStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchOverviewStats();
});

/// Provides AI insights for the dashboard.
final insightsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchInsights();
});

/// Provides alerts for notification badge.
final alertsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchAlerts();
});

/// Provides AI discoveries (smart market scanner).
final discoveriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchDiscoveries();
});
