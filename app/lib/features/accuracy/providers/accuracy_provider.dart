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
