     1|import 'package:dio/dio.dart';
     2|import '../constants/app_constants.dart';
     3|
     4|/// Centralized HTTP client with rate limiting and error handling.
     5|class ApiClient {
     6|  late final Dio _dio;
     7|
     8|  ApiClient() {
     9|    _dio = Dio(BaseOptions(
    10|      connectTimeout: const Duration(seconds: 10),
    11|      receiveTimeout: const Duration(seconds: 15),
    12|      headers: {
    13|        'User-Agent': '${AppConstants.appName}/${AppConstants.appVersion}',
    14|        'Accept': 'application/json',
    15|      },
    16|    ));
    17|
    18|    _dio.interceptors.add(LogInterceptor(
    19|      requestBody: false,
    20|      responseBody: false,
    21|    ));
    22|  }
    23|
    24|  /// GET request with retry logic.
    25|  Future<Response<T>> get<T>(
    26|    String url, {
    27|    Map<String, dynamic>? queryParameters,
    28|    int retryCount = 2,
    29|  }) async {
    30|    Exception? lastException;
    31|    for (var i = 0; i <= retryCount; i++) {
    32|      try {
    33|        // MusicBrainz rate limiting
    34|        if (url.contains('musicbrainz.org')) {
    35|          await Future.delayed(AppConstants.musicBrainzRateLimit);
    36|        }
    37|        return await _dio.get<T>(url, queryParameters: queryParameters);
    38|      } on DioException catch (e) {
    39|        lastException = e;
    40|        if (e.type == DioExceptionType.connectionError) {
    41|          await Future.delayed(Duration(seconds: 2 * (i + 1)));
    42|          continue;
    43|        }
    44|        rethrow;
    45|      }
    46|    }
    47|    throw lastException!;
    48|  }
    49|
    50|  Dio get rawDio => _dio;
    51|}
    52|