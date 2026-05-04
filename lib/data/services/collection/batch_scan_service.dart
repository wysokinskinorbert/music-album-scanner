import 'dart:io';
import '../../data/models/album_model.dart';
import '../services/recognition_service.dart';
import '../services/local_storage_service.dart';
import 'package:logger/logger.dart';

/// Status of a single scan in a batch.
enum BatchScanItemStatus {
  pending,
  processing,
  success,
  failed,
  skipped,
}

/// A single item in a batch scan.
class BatchScanItem {
  final String imagePath;
  final int index;
  BatchScanItemStatus status;
  Album? result;
  String? errorMessage;
  double? confidence;

  BatchScanItem({
    required this.imagePath,
    required this.index,
    this.status = BatchScanItemStatus.pending,
    this.result,
    this.errorMessage,
    this.confidence,
  });
}

/// Result of a complete batch scan.
class BatchScanResult {
  final List<BatchScanItem> items;
  final Duration duration;
  final int totalScanned;
  final int successes;
  final int failures;

  const BatchScanResult({
    required this.items,
    required this.duration,
    required this.totalScanned,
    required this.successes,
    required this.failures,
  });

  double get successRate =>
      totalScanned == 0 ? 0 : successes / totalScanned;
}

/// Callback for batch scan progress.
typedef BatchProgressCallback = void Function(
  int current,
  int total,
  BatchScanItem item,
);

/// Service for batch scanning multiple album photos.
class BatchScanService {
  final RecognitionService _recognition;
  final LocalStorageService _storage;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  BatchScanService({
    required RecognitionService recognition,
    required LocalStorageService storage,
  })  : _recognition = recognition,
        _storage = storage;

  /// Run batch scan on a list of image paths.
  Future<BatchScanResult> scanBatch(
    List<String> imagePaths, {
    BatchProgressCallback? onProgress,
    bool skipDuplicates = true,
    int delayBetweenMs = 500,
  }) async {
    final stopwatch = Stopwatch()..start();
    final items = <BatchScanItem>[];

    // Initialize items
    for (int i = 0; i < imagePaths.length; i++) {
      items.add(BatchScanItem(imagePath: imagePaths[i], index: i));
    }

    int successes = 0;
    int failures = 0;

    for (final item in items) {
      // Check if file exists
      final file = File(item.imagePath);
      if (!await file.exists()) {
        item.status = BatchScanItemStatus.failed;
        item.errorMessage = 'File not found';
        failures++;
        onProgress?.call(item.index + 1, items.length, item);
        continue;
      }

      item.status = BatchScanItemStatus.processing;
      onProgress?.call(item.index + 1, items.length, item);

      try {
        // Run recognition
        final result = await _recognition.recognizeAlbum(item.imagePath);

        if (result.album != null) {
          // Check for duplicate if enabled
          if (skipDuplicates) {
            final existing = await _storage.searchAlbums(
              result.album!.title ?? '',
            );
            final isDup = existing.any(
              (a) =>
                  a.artist?.toLowerCase() ==
                      result.album!.artist?.toLowerCase() &&
                  a.title?.toLowerCase() ==
                      result.album!.title?.toLowerCase(),
            );

            if (isDup) {
              item.status = BatchScanItemStatus.skipped;
              item.result = result.album;
              item.confidence = result.confidence;
              onProgress?.call(item.index + 1, items.length, item);
              continue;
            }
          }

          // Save to collection
          await _storage.saveAlbum(result.album!);

          item.status = BatchScanItemStatus.success;
          item.result = result.album;
          item.confidence = result.confidence;
          successes++;
        } else {
          item.status = BatchScanItemStatus.failed;
          item.errorMessage = result.errorMessage ?? 'Recognition failed';
          failures++;
        }
      } catch (e) {
        item.status = BatchScanItemStatus.failed;
        item.errorMessage = e.toString();
        failures++;
      }

      onProgress?.call(item.index + 1, items.length, item);

      // Delay between scans to respect rate limits
      if (delayBetweenMs > 0 && item.index < items.length - 1) {
        await Future.delayed(Duration(milliseconds: delayBetweenMs));
      }
    }

    stopwatch.stop();

    _logger.i(
      'Batch scan complete: $successes/${items.length} in ${stopwatch.elapsed.inSeconds}s',
    );

    return BatchScanResult(
      items: items,
      duration: stopwatch.elapsed,
      totalScanned: items.length,
      successes: successes,
      failures: failures,
    );
  }

  /// Estimate remaining time for a batch scan.
  Duration estimateRemaining(
    int completed,
    int total,
    Duration elapsed,
  ) {
    if (completed == 0) return Duration.zero;
    final avgPerItem = elapsed.milliseconds ~/ completed;
    return Duration(milliseconds: avgPerItem * (total - completed));
  }
}
