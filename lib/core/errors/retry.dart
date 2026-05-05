import 'dart:async';
import 'dart:math';
import 'exceptions.dart';

/// Configuration for retry behavior.
class RetryConfig {
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool Function(AppException error) retryIf;

  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.retryIf = _defaultRetryIf,
  });

  /// Retry on network errors and rate limits only.
  static bool _defaultRetryIf(AppException error) {
    if (error is NetworkException) {
      return error.isTimeout || error.isNoConnection || error.isRateLimited;
    }
    if (error is ApiException) {
      return error.code == 'SERVICE_UNAVAILABLE';
    }
    return false;
  }

  /// Retry on any transient error.
  static const aggressive = RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 60),
    backoffMultiplier: 2.0,
  );

  /// No retry - fail immediately.
  static const none = RetryConfig(maxAttempts: 1);

  /// For API calls with strict rate limits (MusicBrainz: 1 req/sec).
  static const rateLimited = RetryConfig(
    maxAttempts: 3,
    baseDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 30),
    backoffMultiplier: 2.0,
  );
}

/// Executes a function with retry logic and exponential backoff.
///
/// Example:
/// ```dart
/// final result = await withRetry(
///   () => apiClient.get('/release/$id'),
///   config: RetryConfig.rateLimited,
///   onRetry: (attempt, error) => log('Retry $attempt: $error'),
/// );
/// ```
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  RetryConfig config = const RetryConfig(),
  void Function(int attempt, AppException error)? onRetry,
}) async {
  int attempt = 0;
  final random = Random();

  while (true) {
    attempt++;
    try {
      return await fn();
    } on AppException catch (e) {
      if (attempt >= config.maxAttempts || !config.retryIf(e)) {
        rethrow;
      }

      // Exponential backoff with jitter
      final delayMs = config.baseDelay.inMilliseconds *
          pow(config.backoffMultiplier, attempt - 1).toInt();
      final jitterMs = random.nextInt(500); // 0-500ms jitter
      final totalDelayMs = min(delayMs + jitterMs, config.maxDelay.inMilliseconds);

      onRetry?.call(attempt, e);

      await Future.delayed(Duration(milliseconds: totalDelayMs));
    }
  }
}

/// Result of a retry operation with metadata.
class RetryResult<T> {
  final T data;
  final int attempts;
  final Duration totalDelay;
  final bool wasRetried;

  const RetryResult({
    required this.data,
    required this.attempts,
    required this.totalDelay,
    required this.wasRetried,
  });
}

/// Executes with retry and returns detailed result.
Future<RetryResult<T>> withRetryResult<T>(
  Future<T> Function() fn, {
  RetryConfig config = const RetryConfig(),
  void Function(int attempt, AppException error)? onRetry,
}) async {
  int attempt = 0;
  int totalDelayMs = 0;
  final random = Random();
  final stopwatch = Stopwatch()..start();

  while (true) {
    attempt++;
    try {
      final data = await fn();
      stopwatch.stop();
      return RetryResult(
        data: data,
        attempts: attempt,
        totalDelay: stopwatch.elapsed,
        wasRetried: attempt > 1,
      );
    } on AppException catch (e) {
      if (attempt >= config.maxAttempts || !config.retryIf(e)) {
        rethrow;
      }

      final delayMs = config.baseDelay.inMilliseconds *
          pow(config.backoffMultiplier, attempt - 1).toInt();
      final jitterMs = random.nextInt(500);
      final actualDelayMs = min(delayMs + jitterMs, config.maxDelay.inMilliseconds);
      totalDelayMs += actualDelayMs;

      onRetry?.call(attempt, e);
      await Future.delayed(Duration(milliseconds: actualDelayMs));
    }
  }
}
