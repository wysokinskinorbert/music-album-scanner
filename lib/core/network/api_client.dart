import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

/// Centralized HTTP client with rate limiting and error handling.
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': '${AppConstants.appName}/${AppConstants.appVersion}',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
    ));
  }

  /// GET request with retry logic.
  Future<Response<T>> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    int retryCount = 2,
  }) async {
    Exception? lastException;
    for (var i = 0; i <= retryCount; i++) {
      try {
        // MusicBrainz rate limiting
        if (url.contains('musicbrainz.org')) {
          await Future.delayed(AppConstants.musicBrainzRateLimit);
        }
        return await _dio.get<T>(url, queryParameters: queryParameters);
      } on DioException catch (e) {
        lastException = e;
        if (e.type == DioExceptionType.tooManyRequests) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
          continue;
        }
        rethrow;
      }
    }
    throw lastException!;
  }

  Dio get rawDio => _dio;
}
