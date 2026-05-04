import '../../core/network/api_client.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/constants/app_constants.dart';
import '../models/recognition_result.dart';
import 'api/musicbrainz_service.dart';
import 'api/discogs_service.dart';
import 'ml/text_extraction_service.dart';
import 'ml/image_labeling_service.dart';
import 'ml/barcode_scanning_service.dart';
import 'ml/offline_recognition_service.dart';

/// Orchestrates the full album recognition pipeline.
///
/// Strategy priority:
///   1. Barcode scan (EAN/UPC) -> direct MusicBrainz lookup
///   2. OCR text extraction -> MusicBrainz search -> Discogs fallback
///   3. Image labeling (visual analysis) -> context-assisted search
///   4. Offline TFLite model (if downloaded)
class RecognitionService {
  final MusicBrainzService _musicBrainz;
  final DiscogsService _discogs;
  final OfflineRecognitionService _offline;
  final ConnectivityService _connectivity;
  final TextExtractionService _textExtractor;
  final ImageLabelingService _imageLabeler;
  final BarcodeScanningService _barcodeScanner;

  RecognitionService({
    required ApiClient apiClient,
    required ConnectivityService connectivity,
  })  : _musicBrainz = MusicBrainzService(apiClient),
        _discogs = DiscogsService(apiClient),
        _offline = OfflineRecognitionService(),
        _connectivity = connectivity,
        _textExtractor = TextExtractionService(),
        _imageLabeler = ImageLabelingService(),
        _barcodeScanner = BarcodeScanningService();

  /// Main recognition entry point.
  /// Runs the full pipeline and returns the best result.
  Future<RecognitionPipelineResult> recognizeAlbum(String imagePath) async {
    final pipelineResults = <RecognitionStep>[];

    // Step 1: Try barcode scanning (fastest, most accurate)
    final barcodeResult = await _tryBarcodeRecognition(imagePath);
    pipelineResults.add(RecognitionStep(
      name: 'Barcode Scan',
      success: barcodeResult != null,
      confidence: barcodeResult?.confidence ?? 0,
    ));
    if (barcodeResult != null && barcodeResult.isSuccess && barcodeResult.isHighConfidence) {
      return RecognitionPipelineResult(
        bestResult: barcodeResult,
        allResults: [barcodeResult],
        pipeline: pipelineResults,
        coverAnalysis: null,
        extractedText: null,
      );
    }

    // If offline, skip online steps
    if (!_connectivity.isOnline) {
      final offlineResult = await _tryOfflineRecognition(imagePath);
      pipelineResults.add(RecognitionStep(
        name: 'Offline Model',
        success: offlineResult != null,
        confidence: offlineResult?.confidence ?? 0,
      ));
      return RecognitionPipelineResult(
        bestResult: offlineResult ?? const RecognitionResult(
          confidence: 0,
          source: 'none',
          errorMessage: 'No internet connection and offline model not available.',
        ),
        allResults: [if (offlineResult != null) offlineResult],
        pipeline: pipelineResults,
        coverAnalysis: null,
        extractedText: null,
      );
    }

    // Step 2: OCR text extraction + MusicBrainz search
    CoverAnalysis? coverAnalysis;
    ExtractedText? extractedText;

    final textResult = await _textExtractor.extractText(imagePath);
    extractedText = textResult;

    // Also analyze the cover visually in parallel
    coverAnalysis = await _imageLabeler.analyzeCover(imagePath);

    if (textResult.hasText) {
      // Generate multiple search queries from extracted text
      final queries = _textExtractor.generateSearchQueries(textResult);

      for (final query in queries.take(3)) {
        final ocrResult = await _searchWithFallback(query);
        pipelineResults.add(RecognitionStep(
          name: 'OCR: "${query.length > 30 ? '${query.substring(0, 30)}...' : query}"',
          success: ocrResult.isSuccess,
          confidence: ocrResult.confidence,
        ));

        if (ocrResult.isSuccess && ocrResult.confidence >= 0.7) {
          return RecognitionPipelineResult(
            bestResult: ocrResult,
            allResults: [if (barcodeResult != null) barcodeResult, ocrResult],
            pipeline: pipelineResults,
            coverAnalysis: coverAnalysis,
            extractedText: extractedText,
          );
        }
      }
    }

    // Step 3: Visual label-assisted search
    if (coverAnalysis.labels.isNotEmpty) {
      final visualResult = await _tryVisualSearch(coverAnalysis, textResult);
      pipelineResults.add(RecognitionStep(
        name: 'Visual Analysis',
        success: visualResult?.isSuccess ?? false,
        confidence: visualResult?.confidence ?? 0,
      ));
      if (visualResult != null && visualResult.isSuccess) {
        return RecognitionPipelineResult(
          bestResult: visualResult,
          allResults: [
            if (barcodeResult != null) barcodeResult,
            visualResult,
          ],
          pipeline: pipelineResults,
          coverAnalysis: coverAnalysis,
          extractedText: extractedText,
        );
      }
    }

    // Step 4: Offline model as last resort
    if (_offline.isModelLoaded) {
      final offlineResult = await _tryOfflineRecognition(imagePath);
      pipelineResults.add(RecognitionStep(
        name: 'Offline Model',
        success: offlineResult != null,
        confidence: offlineResult?.confidence ?? 0,
      ));
      if (offlineResult != null) {
        return RecognitionPipelineResult(
          bestResult: offlineResult,
          allResults: [
            if (barcodeResult != null) barcodeResult,
            offlineResult,
          ],
          pipeline: pipelineResults,
          coverAnalysis: coverAnalysis,
          extractedText: extractedText,
        );
      }
    }

    // Nothing worked
    return RecognitionPipelineResult(
      bestResult: RecognitionResult(
        confidence: _bestConfidence(pipelineResults),
        source: 'none',
        errorMessage: _buildErrorMessage(pipelineResults, textResult),
      ),
      allResults: [if (barcodeResult != null) barcodeResult],
      pipeline: pipelineResults,
      coverAnalysis: coverAnalysis,
      extractedText: extractedText,
    );
  }

  /// Search by barcode (EAN/UPC).
  Future<RecognitionResult?> _tryBarcodeRecognition(String imagePath) async {
    final result = await _barcodeScanner.scanImage(imagePath);

    if (!result.hasBarcode || !result.isAlbumBarcode) {
      return null;
    }

    // Direct MusicBrainz lookup by barcode
    try {
      final releases = await _musicBrainz.searchByBarcode(result.barcode);
      if (releases.isNotEmpty) {
        final parsed = _musicBrainz.parseRelease(releases[0]);

        // Try to get cover art
        final mbid = parsed['musicBrainzId'] as String?;
        String? coverUrl;
        if (mbid != null) {
          coverUrl = await _musicBrainz.getCoverArtUrl(mbid);
        }

        return RecognitionResult(
          albumTitle: parsed['title'],
          artist: parsed['artist'],
          confidence: 0.95,
          source: 'barcode',
          rawApiData: {
            ...parsed,
            if (coverUrl != null) 'coverArtUrl': coverUrl,
            'barcode': result.barcode,
            'barcodeFormat': result.format,
          },
        );
      }
    } catch (_) {}

    // Fallback: search Discogs by barcode
    try {
      final results = await _discogs.search(query: result.barcode);
      if (results.isNotEmpty) {
        final releaseId = int.tryParse(results[0]['id']?.toString() ?? '');
        if (releaseId != null) {
          final release = await _discogs.getRelease(releaseId);
          if (release != null) {
            final parsed = _discogs.parseRelease(release);
            return RecognitionResult(
              albumTitle: parsed['title'],
              artist: parsed['artist'],
              confidence: 0.90,
              source: 'barcode',
              rawApiData: {
                ...parsed,
                'barcode': result.barcode,
              },
            );
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Search MusicBrainz with query, fall back to Discogs.
  Future<RecognitionResult> _searchWithFallback(String query) async {
    // Try MusicBrainz first
    try {
      final releases = await _musicBrainz.searchRelease(query: query, limit: 3);
      if (releases.isNotEmpty) {
        final parsed = _musicBrainz.parseRelease(releases[0]);
        final mbid = parsed['musicBrainzId'] as String?;

        // Enrich with cover art
        String? coverUrl;
        if (mbid != null) {
          coverUrl = await _musicBrainz.getCoverArtUrl(mbid);
        }

        // Enrich with full details if we have a match
        Map<String, dynamic>? fullDetails;
        if (mbid != null) {
          fullDetails = await _musicBrainz.getReleaseDetails(mbid);
        }

        final tracklist = fullDetails != null
            ? _extractTracklist(fullDetails)
            : List<String>.from(parsed['tracklist'] ?? []);

        return RecognitionResult(
          albumTitle: parsed['title'],
          artist: parsed['artist'],
          confidence: _calculateMbConfidence(releases),
          source: 'online',
          rawApiData: {
            ...parsed,
            'tracklist': tracklist,
            if (coverUrl != null) 'coverArtUrl': coverUrl,
          },
        );
      }
    } catch (_) {}

    // Fallback to Discogs
    try {
      final results = await _discogs.search(query: query);
      if (results.isNotEmpty) {
        final releaseId = int.tryParse(results[0]['id']?.toString() ?? '');
        if (releaseId != null) {
          final release = await _discogs.getRelease(releaseId);
          if (release != null) {
            final parsed = _discogs.parseRelease(release);
            return RecognitionResult(
              albumTitle: parsed['title'],
              artist: parsed['artist'],
              confidence: 0.75,
              source: 'online',
              rawApiData: parsed,
            );
          }
        }
      }
    } catch (_) {}

    return const RecognitionResult(
      confidence: 0,
      source: 'online',
      errorMessage: 'No results found',
    );
  }

  /// Try visual label-assisted search.
  Future<RecognitionResult?> _tryVisualSearch(
    CoverAnalysis analysis,
    ExtractedText textResult,
  ) async {
    // Combine visual labels with any text we found
    final searchTerms = <String>[];

    if (textResult.hasText) {
      // Use text as primary, labels as secondary context
      searchTerms.add(textResult.lines.first);
    }

    // Add genre hints from labels
    if (analysis.detectedGenres.isNotEmpty) {
      // This could help narrow down results in a future implementation
    }

    for (final term in searchTerms) {
      final result = await _searchWithFallback(term);
      if (result.isSuccess) {
        return result;
      }
    }

    return null;
  }

  /// Try offline TFLite model.
  Future<RecognitionResult?> _tryOfflineRecognition(String imagePath) async {
    if (!_offline.isModelLoaded) return null;

    final result = await _offline.recognize(imagePath);
    if (result == null) return null;

    // Offline model gives us a label index + confidence
    // In a full implementation, this would map to album data
    return RecognitionResult(
      confidence: result.confidence,
      source: 'offline',
    );
  }

  /// Extract tracklist from MusicBrainz release details.
  List<String> _extractTracklist(Map<String, dynamic> details) {
    final tracks = <String>[];
    final media = details['media'] as List<dynamic>? ?? [];
    for (final medium in media) {
      final trackList = medium['tracks'] as List<dynamic>? ?? [];
      for (final track in trackList) {
        final recording = track['recording'];
        tracks.add(recording?['title'] as String? ?? track['title'] as String? ?? '');
      }
    }
    return tracks;
  }

  /// Calculate confidence based on MusicBrainz result quality.
  double _calculateMbConfidence(List<Map<String, dynamic>> releases) {
    if (releases.isEmpty) return 0;
    if (releases.length == 1) return 0.85;

    // Check if top results are similar (high confidence)
    final firstTitle = releases[0]['title']?.toString().toLowerCase() ?? '';
    int matches = 0;
    for (int i = 1; i < releases.length && i < 3; i++) {
      final title = releases[i]['title']?.toString().toLowerCase() ?? '';
      if (title == firstTitle || firstTitle.contains(title) || title.contains(firstTitle)) {
        matches++;
      }
    }

    if (matches > 0) return 0.9;
    return 0.8;
  }

  double _bestConfidence(List<RecognitionStep> steps) {
    if (steps.isEmpty) return 0;
    return steps.map((s) => s.confidence).reduce((a, b) => a > b ? a : b);
  }

  String _buildErrorMessage(List<RecognitionStep> steps, ExtractedText? text) {
    final parts = <String>[];

    if (text == null || !text.hasText) {
      parts.add('No text found on cover');
    } else {
      parts.add('Text found but no matching albums');
    }

    final barcodeStep = steps.where((s) => s.name == 'Barcode Scan').firstOrNull;
    if (barcodeStep != null && !barcodeStep.success) {
      parts.add('No barcode detected');
    }

    parts.add('Try a clearer photo or search manually');
    return parts.join('. ') + '.';
  }

  /// Quick search by artist + album name (for manual input).
  Future<RecognitionResult> searchByQuery(String artist, String album) async {
    final query = '\${artist.trim()} AND \${album.trim()}';
    return _searchWithFallback(query);
  }

  /// Load the offline TFLite model.
  Future<bool> loadOfflineModel() => _offline.loadModel();

  /// Check if offline model is loaded.
  bool get isOfflineModelLoaded => _offline.isModelLoaded;

  void dispose() {
    _offline.dispose();
    _textExtractor.dispose();
    _imageLabeler.dispose();
    _barcodeScanner.dispose();
  }
}

/// Tracks each step of the recognition pipeline.
class RecognitionStep {
  final String name;
  final bool success;
  final double confidence;

  const RecognitionStep({
    required this.name,
    required this.success,
    required this.confidence,
  });
}

/// Complete result from the recognition pipeline.
class RecognitionPipelineResult {
  final RecognitionResult bestResult;
  final List<RecognitionResult> allResults;
  final List<RecognitionStep> pipeline;
  final CoverAnalysis? coverAnalysis;
  final ExtractedText? extractedText;

  const RecognitionPipelineResult({
    required this.bestResult,
    required this.allResults,
    required this.pipeline,
    required this.coverAnalysis,
    required this.extractedText,
  });

  /// How many pipeline steps were attempted.
  int get stepsAttempted => pipeline.length;

  /// How many pipeline steps succeeded.
  int get stepsSucceeded => pipeline.where((s) => s.success).length;

  /// Pipeline summary for debugging/display.
  String get pipelineSummary =>
      pipeline.map((s) => '\${s.name}: \${s.success ? "OK" : "FAIL"} (\${(s.confidence * 100).toInt()}%)').join(' -> ');
}
