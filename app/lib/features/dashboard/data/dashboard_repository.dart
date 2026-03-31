import 'package:dio/dio.dart';

import '../../../shared/models/judgment.dart';

/// Repository for fetching dashboard data (latest judgments).
class DashboardRepository {
  final Dio _dio;

  DashboardRepository(this._dio);

  /// Fetch the latest judgment for each active market.
  Future<List<Judgment>> fetchLatestJudgments() async {
    final response = await _dio.get('/judgments/latest');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((j) => Judgment.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
