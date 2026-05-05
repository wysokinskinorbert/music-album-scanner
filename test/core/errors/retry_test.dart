import 'package:test/test.dart';
import 'package:music_album_scanner/core/errors/retry.dart';
import 'package:music_album_scanner/core/errors/exceptions.dart';

void main() {
  group('withRetry', () {
    test('succeeds on first attempt', () async {
      int attempts = 0;
      final result = await withRetry(() async {
        attempts++;
        return 42;
      });
      expect(result, 42);
      expect(attempts, 1);
    });

    test('retries on retryable NetworkException and succeeds', () async {
      int attempts = 0;
      final result = await withRetry(() async {
        attempts++;
        if (attempts < 3) throw NetworkException.timeout();
        return 'ok';
      }, config: const RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 10),
      ));
      expect(result, 'ok');
      expect(attempts, 3);
    });

    test('exhausts max attempts and throws', () async {
      int attempts = 0;
      final retryLog = <int>[];
      expect(
        () => withRetry(() async {
          attempts++;
          throw NetworkException.timeout();
        }, config: const RetryConfig(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 10),
        ), onRetry: (a, e) => retryLog.add(a)),
        throwsA(isA<NetworkException>()),
      );
      // Give it time to complete
      await Future.delayed(const Duration(milliseconds: 200));
    });

    test('does not retry non-retryable exceptions', () async {
      int attempts = 0;
      expect(
        () => withRetry(() async {
          attempts++;
          throw const StorageException(message: 'fail', code: 'WRITE_ERROR');
        }, config: const RetryConfig(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 10),
        )),
        throwsA(isA<StorageException>()),
      );
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('retries on rate limit', () async {
      int attempts = 0;
      final result = await withRetry(() async {
        attempts++;
        if (attempts < 2) throw NetworkException.rateLimited();
        return 'done';
      }, config: const RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 10),
      ));
      expect(result, 'done');
      expect(attempts, 2);
    });

    test('calls onRetry callback', () async {
      final retryAttempts = <int>[];
      int attempts = 0;
      await withRetry(() async {
        attempts++;
        if (attempts < 3) throw NetworkException.noConnection();
        return 'ok';
      }, config: const RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 10),
      ), onRetry: (a, e) => retryAttempts.add(a));
      expect(retryAttempts, [1, 2]);
    });

    test('RetryConfig.none fails immediately', () async {
      int attempts = 0;
      try {
        await withRetry(() async {
          attempts++;
          throw NetworkException.timeout();
        }, config: RetryConfig.none);
      } on NetworkException {
        // expected
      }
      expect(attempts, 1);
    });
  });

  group('withRetryResult', () {
    test('returns result with metadata', () async {
      final result = await withRetryResult(() async => 99);
      expect(result.data, 99);
      expect(result.attempts, 1);
      expect(result.wasRetried, isFalse);
    });

    test('wasRetried is true after retry', () async {
      int attempts = 0;
      final result = await withRetryResult(() async {
        attempts++;
        if (attempts < 2) throw NetworkException.timeout();
        return 'retried';
      }, config: const RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 10),
      ));
      expect(result.data, 'retried');
      expect(result.wasRetried, isTrue);
      expect(result.attempts, 2);
    });
  });

  group('RetryConfig presets', () {
    test('default has 3 max attempts', () {
      const config = RetryConfig();
      expect(config.maxAttempts, 3);
    });

    test('aggressive has 5 max attempts', () {
      const config = RetryConfig.aggressive;
      expect(config.maxAttempts, 5);
    });

    test('none has 1 max attempt', () {
      const config = RetryConfig.none;
      expect(config.maxAttempts, 1);
    });

    test('rateLimited has 2s base delay', () {
      const config = RetryConfig.rateLimited;
      expect(config.baseDelay, const Duration(seconds: 2));
    });
  });
}
