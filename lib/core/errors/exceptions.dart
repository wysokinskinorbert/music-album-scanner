/// Base exception for all app errors.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => '\$runtimeType: \$message\${code != null ? " (\$code)" : ""}';
}

/// Network-related errors (no internet, timeout, DNS failure).
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException({
    required super.message,
    super.code,
    this.statusCode,
    super.originalError,
    super.stackTrace,
  });

  /// No internet connection.
  factory NetworkException.noConnection({dynamic originalError}) =>
      NetworkException(
        message: 'No internet connection',
        code: 'NO_CONNECTION',
        originalError: originalError,
      );

  /// Request timed out.
  factory NetworkException.timeout({dynamic originalError}) =>
      NetworkException(
        message: 'Request timed out',
        code: 'TIMEOUT',
        originalError: originalError,
      );

  /// Server returned an error status code.
  factory NetworkException.httpError(int statusCode, {String? body}) =>
      NetworkException(
        message: 'HTTP error \$statusCode',
        code: 'HTTP_\$statusCode',
        statusCode: statusCode,
        originalError: body,
      );

  /// Rate limited (429).
  factory NetworkException.rateLimited({int? retryAfter}) =>
      NetworkException(
        message: 'Rate limited\${retryAfter != null ? " (retry after \${retryAfter}s)" : ""}',
        code: 'RATE_LIMITED',
        statusCode: 429,
      );

  bool get isNoConnection => code == 'NO_CONNECTION';
  bool get isTimeout => code == 'TIMEOUT';
  bool get isRateLimited => code == 'RATE_LIMITED';
}

/// API-specific errors (bad response, parsing failed, etc).
class ApiException extends AppException {
  final String service; // 'musicbrainz', 'discogs', 'coverart'

  const ApiException({
    required super.message,
    required this.service,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Failed to parse API response.
  factory ApiException.parseError(String service, {dynamic originalError}) =>
      ApiException(
        message: 'Failed to parse \$service response',
        service: service,
        code: 'PARSE_ERROR',
        originalError: originalError,
      );

  /// No results found from the API.
  factory ApiException.noResults(String service) => ApiException(
        message: 'No results from \$service',
        service: service,
        code: 'NO_RESULTS',
      );

  /// API service is unavailable.
  factory ApiException.serviceUnavailable(String service) => ApiException(
        message: '\$service is currently unavailable',
        service: service,
        code: 'SERVICE_UNAVAILABLE',
      );
}

/// Storage-related errors (Hive, file I/O).
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory StorageException.writeError({dynamic originalError}) =>
      StorageException(
        message: 'Failed to write data',
        code: 'WRITE_ERROR',
        originalError: originalError,
      );

  factory StorageException.readError({dynamic originalError}) =>
      StorageException(
        message: 'Failed to read data',
        code: 'READ_ERROR',
        originalError: originalError,
      );

  factory StorageException.deleteError({dynamic originalError}) =>
      StorageException(
        message: 'Failed to delete data',
        code: 'DELETE_ERROR',
        originalError: originalError,
      );

  factory StorageException.boxNotOpen(String boxName) => StorageException(
        message: 'Box "\$boxName" is not open',
        code: 'BOX_NOT_OPEN',
      );
}

/// Recognition pipeline errors.
class RecognitionException extends AppException {
  final String stage; // 'barcode', 'ocr', 'labeling', 'search', 'offline'

  const RecognitionException({
    required super.message,
    required this.stage,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory RecognitionException.stageFailed(String stage, {dynamic error}) =>
      RecognitionException(
        message: 'Recognition failed at stage: \$stage',
        stage: stage,
        code: 'STAGE_FAILED',
        originalError: error,
      );

  factory RecognitionException.noAlbumFound() => RecognitionException(
        message: 'Could not identify album',
        stage: 'all',
        code: 'NO_ALBUM_FOUND',
      );

  factory RecognitionException.lowConfidence(double confidence) =>
      RecognitionException(
        message: 'Recognition confidence too low: \${(confidence * 100).toStringAsFixed(1)}%',
        stage: 'all',
        code: 'LOW_CONFIDENCE',
      );

  factory RecognitionException.cameraError({dynamic error}) =>
      RecognitionException(
        message: 'Camera error during scan',
        stage: 'camera',
        code: 'CAMERA_ERROR',
        originalError: error,
      );

  factory RecognitionException.imageError({dynamic error}) =>
      RecognitionException(
        message: 'Failed to process image',
        stage: 'image',
        code: 'IMAGE_ERROR',
        originalError: error,
      );
}

/// Permission-related errors.
class PermissionException extends AppException {
  final String permission;

  const PermissionException({
    required super.message,
    required this.permission,
    super.code,
  });

  factory PermissionException.camera() => PermissionException(
        message: 'Camera permission is required to scan albums',
        permission: 'camera',
        code: 'CAMERA_DENIED',
      );

  factory PermissionException.storage() => PermissionException(
        message: 'Storage permission is required to save photos',
        permission: 'storage',
        code: 'STORAGE_DENIED',
      );

  factory PermissionException.photos() => PermissionException(
        message: 'Photos permission is required to access gallery',
        permission: 'photos',
        code: 'PHOTOS_DENIED',
      );
}
