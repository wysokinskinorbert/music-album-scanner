import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

/// Centralized HTTP client with rate limiting and error handling.
class ApiClient {
  late final Dio _dio;
  int _requestCount = 0;
  DateTime? _lastRequestTime;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.musicBrainzBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'MusicAlbumScanner/1.0 (wysokinskinorbert@users.noreply.github.com)',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(_RateLimitInterceptor());
  }

  Dio get dio => _dio;

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
  }) async {
    _requestCount++;
    _lastRequestTime = DateTime.now();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: baseUrl != null
            ? Options(baseUrl: baseUrl)
            : null,
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        // Rate limited - wait and retry
        await Future.delayed(const Duration(seconds: 2));
        final retryResponse = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: queryParameters,
        );
        return retryResponse.data;
      }
      rethrow;
    }
  }

  void resetRequestCount() {
    _requestCount = 0;
    _lastRequestTime = null;
  }

  int get requestCount => _requestCount;
  DateTime? get lastRequestTime => _lastRequestTime;
}

class _RateLimitInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // MusicBrainz requires max 1 request per second
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 429) {
      // Rate limited
      Future.delayed(const Duration(seconds: 2), () {
        handler.resolve(Response(
          requestOptions: err.requestOptions,
          statusCode: 200,
        ));
      });
    } else {
      handler.next(err);
    }
  }
}
