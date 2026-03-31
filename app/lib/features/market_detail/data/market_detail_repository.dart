import 'package:dio/dio.dart';

import '../../../shared/models/judgment.dart';
import '../../../shared/models/market.dart';

/// Repository for fetching a single market's detail and judgment history.
class MarketDetailRepository {
  final Dio _dio;

  MarketDetailRepository(this._dio);

  /// Fetch market by symbol.
  Future<Market> fetchMarket(String symbol) async {
    final response = await _dio.get('/markets/$symbol');
    return Market.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetch judgment history for a specific market symbol.
  Future<List<Judgment>> fetchJudgments(String symbol,
      {int page = 1, int pageSize = 20}) async {
    final response = await _dio.get('/judgments', queryParameters: {
      'symbol': symbol,
      'page': page,
      'page_size': pageSize,
    });
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((j) => Judgment.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
