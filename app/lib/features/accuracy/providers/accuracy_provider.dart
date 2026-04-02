import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../../../shared/models/accuracy.dart';
import '../data/accuracy_repository.dart';

final accuracyRepositoryProvider = Provider<AccuracyRepository>((ref) {
  return AccuracyRepository(ref.watch(dioProvider));
});

/// Provides overall accuracy stats.
final accuracyProvider = FutureProvider<List<AccuracyStat>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchAccuracy();
});

/// Provides accuracy history for trend chart.
final accuracyHistoryProvider =
    FutureProvider<List<AccuracyHistoryItem>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchAccuracyHistory();
});

/// Provides calibration curve data.
final calibrationProvider =
    FutureProvider<List<CalibrationPoint>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchCalibration();
});

/// Provides bias report data.
final biasReportProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchBiasReport();
});

/// Provides accuracy by hour data.
final accuracyByHourProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchAccuracyByHour();
});

/// Provides strategy genome status.
final genomeStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchGenomeStatus();
});

/// Provides Brier score data from overview (R13).
final brierScoreProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchOverviewStats();
});

/// Provides overview stats for evolution page's market sentiment section.
final overviewStatsForEvolutionProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchOverviewStats();
});

/// Provides meta-learning insights (L4).
final metaInsightsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(accuracyRepositoryProvider);
  return repo.fetchMetaInsights();
});
