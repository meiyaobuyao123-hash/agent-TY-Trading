import 'package:dio/dio.dart';

import '../../../shared/models/accuracy.dart';

/// Repository for fetching accuracy statistics.
class AccuracyRepository {
  final Dio _dio;

  AccuracyRepository(this._dio);

  /// Fetch overall accuracy stats across all market types.
  Future<List<AccuracyStat>> fetchAccuracy() async {
    final response = await _dio.get('/accuracy');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((a) => AccuracyStat.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Fetch accuracy for a specific market type.
  Future<List<AccuracyStat>> fetchAccuracyByType(String marketType) async {
    final response = await _dio.get('/accuracy/$marketType');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((a) => AccuracyStat.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Fetch accuracy history (trend over time).
  Future<List<AccuracyHistoryItem>> fetchAccuracyHistory() async {
    final response = await _dio.get('/stats/accuracy-history');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((a) => AccuracyHistoryItem.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Fetch calibration curve data.
  Future<List<CalibrationPoint>> fetchCalibration() async {
    final response = await _dio.get('/accuracy/calibration');
    final data = response.data as Map<String, dynamic>;
    final points = data['points'] as List<dynamic>;
    return points
        .map((p) => CalibrationPoint.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Fetch bias report for cognitive bias analysis.
  Future<Map<String, dynamic>> fetchBiasReport() async {
    final response = await _dio.get('/stats/bias-report');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch accuracy by hour of day.
  Future<Map<String, dynamic>> fetchAccuracyByHour() async {
    final response = await _dio.get('/stats/accuracy-by-hour');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch strategy genome status.
  Future<Map<String, dynamic>> fetchGenomeStatus() async {
    final response = await _dio.get('/stats/genome-status');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch overview stats (includes Brier score, R13).
  Future<Map<String, dynamic>> fetchOverviewStats() async {
    final response = await _dio.get('/stats/overview');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch meta-learning insights (L4).
  Future<Map<String, dynamic>> fetchMetaInsights() async {
    final response = await _dio.get('/stats/meta-insights');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch evolution timeline milestones.
  Future<List<Map<String, dynamic>>> fetchEvolutionTimeline() async {
    final response = await _dio.get('/stats/evolution-timeline');
    final data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Fetch leaderboard (top/bottom markets by accuracy).
  Future<Map<String, dynamic>> fetchLeaderboard() async {
    final response = await _dio.get('/stats/leaderboard');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch calibration chart data (5-bucket predicted vs actual).
  Future<Map<String, dynamic>> fetchCalibrationChart() async {
    final response = await _dio.get('/stats/calibration-chart');
    return response.data as Map<String, dynamic>;
  }
}
