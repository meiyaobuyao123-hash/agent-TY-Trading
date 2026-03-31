import 'package:dio/dio.dart';

import '../../../shared/models/market.dart';

/// Repository for fetching market list.
class MarketsRepository {
  final Dio _dio;

  MarketsRepository(this._dio);

  /// Fetch all tracked markets.
  Future<List<Market>> fetchMarkets() async {
    final response = await _dio.get('/markets');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((m) => Market.fromJson(m as Map<String, dynamic>))
        .toList();
  }
}
