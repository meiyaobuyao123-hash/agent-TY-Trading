/// API configuration constants for TY Trading.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'http://43.156.207.26/api/ty';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
