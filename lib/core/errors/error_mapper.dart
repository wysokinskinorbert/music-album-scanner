import 'package:dio/dio.dart';
import 'exceptions.dart';

/// Converts raw errors (DioException, etc.) into typed AppExceptions.
class ErrorMapper {
  /// Map a DioException to the appropriate AppException.
  static AppException fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException.timeout(originalError: error);

      case DioExceptionType.connectionError:
        return NetworkException.noConnection(originalError: error);

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 429) {
          final retryAfter = error.response?.headers['retry-after']?.first;
          return NetworkException.rateLimited(
            retryAfter: retryAfter != null ? int.tryParse(retryAfter) : null,
          );
        }
        return NetworkException.httpError(
          statusCode ?? 0,
          body: error.response?.data?.toString(),
        );

      case DioExceptionType.cancel:
        return const NetworkException(message: 'Request was cancelled', code: 'CANCELLED');

      case DioExceptionType.badCertificate:
        return const NetworkException(message: 'Certificate verification failed', code: 'BAD_CERT');

      case DioExceptionType.unknown:
        if (error.error?.toString().contains('SocketException') == true) {
          return NetworkException.noConnection(originalError: error);
        }
        return NetworkException(
          message: error.message ?? 'Unknown network error',
          code: 'UNKNOWN',
          originalError: error,
        );
    }
  }

  /// Map any error to AppException.
  static AppException fromDynamic(dynamic error, {StackTrace? stackTrace}) {
    if (error is AppException) return error;
    if (error is DioException) return fromDioError(error);
    if (error is FormatException) {
      return ApiException.parseError('unknown', originalError: error);
    }
    if (error is TypeError) {
      return ApiException(
        message: 'Data type error: \${error.toString()}',
        service: 'unknown',
        code: 'TYPE_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    return AppException(
      message: error.toString(),
      code: 'UNKNOWN',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Get a user-friendly message from any error.
  static String userMessage(dynamic error) {
    if (error is AppException) {
      if (error is NetworkException) {
        if (error.isNoConnection) {
          return 'Brak polaczenia z internetem. Sprawdz ustawienia sieci.';
        }
        if (error.isTimeout) {
          return 'Serwer nie odpowiada. Sprobuj ponownie za chwile.';
        }
        if (error.isRateLimited) {
          return 'Zbyt wiele zapytan. Odczekaj chwile i sprobuj ponownie.';
        }
      }
      if (error is ApiException && error.code == 'NO_RESULTS') {
        return 'Nie znaleziono albumu. Sprobuj zrobic zdjecie z innej strony.';
      }
      if (error is RecognitionException) {
        if (error.code == 'LOW_CONFIDENCE') {
          return 'Rozpoznanie niepewne. Sprobuj zrobic wyrazniejsze zdjecie.';
        }
        if (error.code == 'NO_ALBUM_FOUND') {
          return 'Nie udalo sie rozpoznac albumu. Sprobuj recznego wyszukiwania.';
        }
      }
      if (error is PermissionException) {
        return error.message;
      }
      return error.message;
    }
    return 'Wystapil nieoczekiwany blad. Sprobuj ponownie.';
  }
}
