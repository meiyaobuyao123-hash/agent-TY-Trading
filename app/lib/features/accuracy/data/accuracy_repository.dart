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
}
