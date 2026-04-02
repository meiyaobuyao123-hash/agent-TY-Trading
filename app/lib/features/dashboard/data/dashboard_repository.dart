import 'package:dio/dio.dart';

import '../../../shared/models/judgment.dart';

/// Repository for fetching dashboard data (latest judgments + stats).
class DashboardRepository {
  final Dio _dio;

  DashboardRepository(this._dio);

  /// Fetch the latest judgment for each active market (brief mode for list).
  Future<List<Judgment>> fetchLatestJudgments() async {
    final response = await _dio.get('/judgments/latest', queryParameters: {
      'brief': true,
    });
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((j) => Judgment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Fetch system overview stats for AI evolution section.
  Future<Map<String, dynamic>> fetchOverviewStats() async {
    final response = await _dio.get('/stats/overview');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch AI insights for the insights section.
  Future<Map<String, dynamic>> fetchInsights() async {
    final response = await _dio.get('/stats/insights');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch alerts for the notification infrastructure.
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    final response = await _dio.get('/stats/alerts');
    final data = response.data as Map<String, dynamic>;
    final alerts = data['alerts'] as List<dynamic>? ?? [];
    return alerts.cast<Map<String, dynamic>>();
  }

  /// Fetch AI discoveries (smart market scanner).
  Future<List<Map<String, dynamic>>> fetchDiscoveries() async {
    final response = await _dio.get('/stats/discoveries');
    final data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Fetch system health status for the live indicator.
  Future<Map<String, dynamic>> fetchHealth() async {
    final response = await _dio.get('/health');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch daily report (日报).
  Future<Map<String, dynamic>> fetchDailyReport() async {
    final response = await _dio.get('/stats/daily-report');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch macro signals (宏观信号).
  Future<Map<String, dynamic>> fetchMacroSignals() async {
    final response = await _dio.get('/stats/macro-signals');
    return response.data as Map<String, dynamic>;
  }
}
