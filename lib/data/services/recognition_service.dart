import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/album_model.dart';
import '../models/recognition_result.dart';
import 'api/musicbrainz_service.dart';
import 'api/discogs_service.dart';
import 'api/cloud_vision_service.dart';
import 'ml/barcode_scanning_service.dart';
import 'ml/text_extraction_service.dart';
import 'ml/image_labeling_service.dart';
import 'offline/offline_recognition_service.dart';
import 'ml/tflite_inference_service.dart';
import '../../core/network/api_client.dart';

/// Main recognition pipeline service with multi-query scoring.
class RecognitionService {
  final ApiClient _apiClient;
  final MusicBrainzService _musicBrainz;
  final DiscogsService _discogs;
  final CloudVisionService _cloudVision;
  final BarcodeScanningService _barcodeService;
  final TfliteInferenceService? _tfliteService;
  final OfflineRecognitionService? _offlineService;
  final TextExtractionService? _textExtraction;
  final ImageLabelingService? _imageLabeler;

  /// Whether OCR found meaningful text (set during recognition).
  bool _ocrHasText = false;

  RecognitionService({
    required ApiClient apiClient,
    MusicBrainzService? musicBrainz,
    DiscogsService? discogs,
    CloudVisionService? cloudVision,
    BarcodeScanningService? barcodeService,
    TfliteInferenceService? tfliteService,
    OfflineRecognitionService? offlineService,
    TextExtractionService? textExtraction,
    ImageLabelingService? imageLabeler,
  })  : _apiClient = apiClient,
        _musicBrainz = musicBrainz ?? MusicBrainzService(ApiClient()),
        _discogs = discogs ?? DiscogsService(),
        _cloudVision = cloudVision ?? CloudVisionService(),
        _barcodeService = barcodeService ?? BarcodeScanningService(),
        _tfliteService = tfliteService,
        _offlineService = offlineService,
        _textExtraction = textExtraction,
        _imageLabeler = imageLabeler;

  /// Cloud Vision service access for settings UI.
  CloudVisionService get cloudVision => _cloudVision;

  /// Safely parse a 4-digit year from a date string like "2023-05-10" or "2023".
  int? _parseYear(String? dateStr) {
    if (dateStr == null || dateStr.length < 4) return null;
    return int.tryParse(dateStr.substring(0, 4));
  }

  /// Calculate fuzzy match score between OCR text and a MusicBrainz result.
  /// Returns 0.0 - 1.0 where 1.0 = perfect match.
  /// Rejects results where query is too generic (e.g. "Hat" matching "Nits - Hat").
  double _calculateMatchScore(String query, String artist, String title) {
    final queryLower = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    final artistLower = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    final titleLower = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    final combinedLower = '$artistLower $titleLower';
    final combinedReverse = '$titleLower $artistLower';

    // Reject very short queries (likely false positives from ImageLabeler)
    if (queryLower.length < 3) return 0.0;

    // Reject single-word queries that are common/generic words
    final genericWords = {'hat', 'neon', 'insect', 'gold', 'disc', 'blue', 'red', 'black', 'white',
      'original', 'remaster', 'digital', 'analog', 'vinyl', 'cd', 'lp', 'ep'};
    final queryWords = queryLower.split(RegExp(r'\s+'));
    if (queryWords.length == 1 && genericWords.contains(queryLower)) {
      return 0.0; // Generic single word should not match anything
    }

    double score = 0.0;

    // Count how many query words appear in artist or title
    int matchedWords = 0;
    int meaningfulWords = 0;
    for (final word in queryWords) {
      if (word.length < 3) continue; // Skip short words
      meaningfulWords++;
      if (artistLower.contains(word) || titleLower.contains(word)) {
        matchedWords++;
      }
    }
    if (meaningfulWords == 0) return 0.0;
    score = matchedWords / meaningfulWords;

    // Bonus: query is a substring of "Artist Title" or "Title Artist"
    if (combinedLower.contains(queryLower) || combinedReverse.contains(queryLower)) {
      score += 0.3;
    }

    // Bonus: exact artist match
    if (artistLower == queryLower || queryLower.contains(artistLower)) {
      score += 0.2;
    }

    // Penalty: if query is a single word and it's only in the title (not artist),
    // it's likely a false positive (e.g. "Hat" -> "Nits - Hat")
    if (queryWords.length == 1 && titleLower.contains(queryLower) && !artistLower.contains(queryLower)) {
      score *= 0.3; // Heavy penalty for single-word title-only matches
    }

    // Penalty: if artist is completely different from all query words
    bool artistHasAnyWord = false;
    for (final word in queryWords) {
      if (word.length >= 3 && artistLower.contains(word)) {
        artistHasAnyWord = true;
        break;
      }
    }
    if (!artistHasAnyWord && meaningfulWords > 0) {
      score *= 0.5; // Penalty when artist doesn't match any query word
    }

    return score.clamp(0.0, 1.0);
  }

  /// Main recognition pipeline
  Future<RecognitionResult> recognizeFromImage(String imagePath) async {
    debugPrint('══════════════════════════════════════════');
    debugPrint('[Recognition] START recognizeFromImage path="$imagePath"');
    debugPrint('══════════════════════════════════════════');
    _ocrHasText = false;

    try {
      // Verify file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('[Recognition] ERROR: file does not exist!');
        return RecognitionResult(
          state: RecognitionState.error,
          message: 'Image file not found: $imagePath',
        );
      }
      final fileSize = await file.length();
      debugPrint('[Recognition] File size: ${fileSize ~/ 1024}KB');

      // Step 1: Try barcode scanning
      debugPrint('[Recognition] Step 1: Barcode scanning...');
      final barcodeResult = await _barcodeService.scanImage(imagePath);
      debugPrint('[Recognition] Barcode result: ${barcodeResult.barcode ?? "none"}');
      if (barcodeResult.barcode != null && barcodeResult.barcode!.isNotEmpty) {
        final album = await _searchByBarcode(barcodeResult.barcode!);
        if (album != null) {
          debugPrint('[Recognition] FOUND via barcode: ${album.artist} - ${album.title}');
          return RecognitionResult(
            state: RecognitionState.success,
            album: album,
            confidence: album.recognitionConfidence,
            source: 'barcode',
            message: 'Found via barcode',
          );
        }
      }

      // Step 2: OCR text extraction with filtering
      debugPrint('[Recognition] Step 2: OCR text extraction...');
      List<String> ocrQueries = [];
      if (_textExtraction != null) {
        try {
          final extracted = await _textExtraction!.extractText(imagePath);
          debugPrint('[Recognition] OCR rawText: "${extracted.rawText}"');
          debugPrint('[Recognition] OCR filteredLines: ${extracted.filteredLines}');
          debugPrint('[Recognition] OCR hasText: ${extracted.hasText}, blocks: ${extracted.blockCount}');
          if (extracted.hasText) {
            _ocrHasText = extracted.filteredLines.isNotEmpty;
            ocrQueries = _textExtraction!.generateSearchQueries(extracted);
            debugPrint('[Recognition] OCR generated queries: $ocrQueries');
          }
        } catch (e) {
          debugPrint('[Recognition] OCR ERROR: $e');
        }
      }

      // Step 3: MusicBrainz search with ALL queries + scoring
      debugPrint('[Recognition] Step 3: MusicBrainz multi-query search...');
      if (ocrQueries.isNotEmpty) {
        final mbResult = await _searchMusicBrainzScored(ocrQueries);
        if (mbResult != null) {
          return mbResult;
        }
      }

      // Step 4: Image labeling (only if no OCR text found)
      debugPrint('[Recognition] Step 4: Image labeling (artwork-only fallback)...');
      String? labelQuery;
      if (!_ocrHasText && _imageLabeler != null) {
        try {
          final analysis = await _imageLabeler!.analyzeCover(imagePath);
          debugPrint('[Recognition] Labels: ${analysis.labelTexts}');
          debugPrint('[Recognition] CoverType: ${analysis.coverType}, genres: ${analysis.detectedGenres}');
          if (analysis.labels.isNotEmpty) {
            // Only use label if confidence > 0.7
            final bestLabel = analysis.labels.reduce(
              (a, b) => a.confidence > b.confidence ? a : b,
            );
            if (bestLabel.confidence > 0.7) {
              labelQuery = bestLabel.label;
              debugPrint('[Recognition] Best label: "$labelQuery" (${(bestLabel.confidence * 100).toStringAsFixed(0)}%)');
            }
          }
        } catch (e) {
          debugPrint('[Recognition] ImageLabeler ERROR: $e');
        }
      }

      // Step 5: TFLite
      debugPrint('[Recognition] Step 5: TFLite classification...');
      if (labelQuery == null && !_ocrHasText && _tfliteService != null) {
        if (_tfliteService!.isModelLoaded) {
          try {
            final labels = await _tfliteService!.classify(imagePath);
            debugPrint('[Recognition] TFLite labels: $labels');
            if (labels.isNotEmpty) labelQuery = labels.first.key;
          } catch (e) {
            debugPrint('[Recognition] TFLite ERROR: $e');
          }
        }
      }

      // Step 6: Try MusicBrainz with label query
      if (labelQuery != null) {
        debugPrint('[Recognition] Step 6: MB with label query "$labelQuery"...');
        final mbResult = await _searchMusicBrainzScored([labelQuery], minScore: 0.3);
        if (mbResult != null) return mbResult;
      }

      // Step 7: Cloud Vision (for artwork-only covers)
      debugPrint('[Recognition] Step 7: Cloud Vision (Google Cloud Vision API)...');
      if (!_ocrHasText && _cloudVision.isConfigured) {
        try {
          final cvResult = await _cloudVision.identifyAlbumCover(imagePath);
          if (cvResult != null) {
            debugPrint('[Recognition] CloudVision result: $cvResult');
            final artist = cvResult['artist'] ?? '';
            final title = cvResult['title'] ?? '';
            final query = cvResult['query'] ?? '';

            if (artist.isNotEmpty || title.isNotEmpty) {
              // Cloud Vision found artist/title - search MusicBrainz with it
              final cvQuery = (artist.isNotEmpty && title.isNotEmpty)
                  ? '$artist $title'
                  : artist.isNotEmpty ? artist : title;
              final mbResult = await _searchMusicBrainzScored([cvQuery], minScore: 0.2);
              if (mbResult != null) {
                // Add Cloud Vision source tag
                return RecognitionResult(
                  state: mbResult.state,
                  album: mbResult.album,
                  confidence: mbResult.confidence,
                  source: 'cloud_vision',
                  message: mbResult.message,
                );
              }
              // If MB didn't match, use Cloud Vision result directly
              final album = Album(
                id: const Uuid().v4(),
                title: title.isNotEmpty ? title : 'Unknown',
                artist: artist.isNotEmpty ? artist : 'Unknown',
                dateAdded: DateTime.now(),
                recognitionConfidence: 0.4,
                userPhotoPath: imagePath,
              );
              return RecognitionResult(
                state: RecognitionState.success,
                album: album,
                confidence: 0.4,
                source: 'cloud_vision',
                message: 'Identified via Google Cloud Vision',
              );
            } else if (query.isNotEmpty) {
              // Cloud Vision returned labels as query hint
              final mbResult = await _searchMusicBrainzScored([query], minScore: 0.2);
              if (mbResult != null) return mbResult;
            }
          }
        } catch (e) {
          debugPrint('[Recognition] CloudVision ERROR: $e');
        }
      } else if (!_cloudVision.isConfigured) {
        debugPrint('[Recognition] CloudVision not configured (no API key)');
      }

      // Step 8: Offline recognition
      debugPrint('[Recognition] Step 8: Offline recognition...');
      if (_offlineService != null) {
        try {
          final offlineResult = await _offlineService!.recognize(imagePath);
          debugPrint('[Recognition] Offline: recognized=${offlineResult.recognized}, conf=${offlineResult.confidence}');
          if (offlineResult.recognized && offlineResult.confidence >= 0.6) {
            final album = Album(
              id: const Uuid().v4(),
              title: offlineResult.title ?? 'Unknown',
              artist: offlineResult.artist ?? 'Unknown',
              dateAdded: DateTime.now(),
              recognitionConfidence: offlineResult.confidence,
              userPhotoPath: imagePath,
            );
            return RecognitionResult(
              state: RecognitionState.success,
              album: album,
              confidence: offlineResult.confidence,
              source: 'offline',
            );
          }
        } catch (e) {
          debugPrint('[Recognition] Offline ERROR: $e');
        }
      }

      // Step 9: Discogs fallback with all queries
      debugPrint('[Recognition] Step 9: Discogs fallback...');
      final discogsQueries = ocrQueries.isNotEmpty ? ocrQueries : (labelQuery != null ? [labelQuery] : <String>[]);
      for (final query in discogsQueries) {
        try {
          final discogsResults = await _discogs.searchRelease(query);
          debugPrint('[Recognition] Discogs "$query": ${discogsResults.length} results');
          if (discogsResults.isNotEmpty) {
            return RecognitionResult(
              state: RecognitionState.success,
              album: discogsResults.first,
              confidence: 0.4,
              source: 'online',
            );
          }
        } catch (e) {
          debugPrint('[Recognition] Discogs "$query" ERROR: $e');
        }
      }

      debugPrint('[Recognition] ALL STEPS FAILED - returning failure');
      return RecognitionResult(
        state: RecognitionState.failed,
        message: _ocrHasText
            ? 'Could not recognize album. Try taking a clearer photo.'
            : 'No text found on this cover. Enable Google Cloud Vision in Settings for artwork-only covers.',
      );
    } catch (e, stack) {
      debugPrint('[Recognition] PIPELINE CRASH: $e');
      debugPrint('[Recognition] Stack: $stack');
      return RecognitionResult(
        state: RecognitionState.error,
        message: 'Recognition error: $e',
      );
    }
  }

  /// Search MusicBrainz with multiple queries, score results, return best match.
  /// Only returns results above [minScore] threshold.
  Future<RecognitionResult?> _searchMusicBrainzScored(
    List<String> queries, {
    double minScore = 0.4,
  }) async {
    _MatchCandidate? bestMatch;

    for (final query in queries) {
      debugPrint('[Recognition] MB query: "$query"');
      try {
        final mbRaw = await _musicBrainz.searchRelease(query: query, limit: 5);
        for (final release in mbRaw) {
          final artistCredit = release['artist-credit'] as List<dynamic>? ?? [];
          final artistName = artistCredit.isNotEmpty
              ? (artistCredit[0]['name'] ?? artistCredit[0]['artist']?['name'] ?? 'Unknown').toString()
              : 'Unknown';
          final title = release['title']?.toString() ?? 'Unknown';

          final score = _calculateMatchScore(query, artistName, title);
          debugPrint('[Recognition]   MB: "$artistName" - "$title" score=${score.toStringAsFixed(2)}');

          if (score >= minScore && (bestMatch == null || score > bestMatch.score)) {
            bestMatch = _MatchCandidate(
              artist: artistName,
              title: title,
              date: release['date']?.toString(),
              mbid: release['id']?.toString(),
              score: score,
              query: query,
            );
          }
        }
      } catch (e) {
        debugPrint('[Recognition] MB query "$query" ERROR: $e');
      }

      // If we found a good match, no need to try more queries
      if (bestMatch != null && bestMatch.score >= 0.7) break;
    }

    if (bestMatch != null) {
      debugPrint('[Recognition] BEST MATCH: "${bestMatch.artist}" - "${bestMatch.title}" '
          'score=${bestMatch.score.toStringAsFixed(2)} query="${bestMatch.query}"');
      final album = Album(
        id: const Uuid().v4(),
        title: bestMatch.title,
        artist: bestMatch.artist,
        releaseYear: _parseYear(bestMatch.date),
        dateAdded: DateTime.now(),
        musicBrainzId: bestMatch.mbid,
        recognitionConfidence: bestMatch.score,
        userPhotoPath: '', // Will be set by caller
      );
      return RecognitionResult(
        state: RecognitionState.success,
        album: album,
        confidence: bestMatch.score,
        source: 'online',
        message: 'Found via MusicBrainz (score: ${(bestMatch.score * 100).toStringAsFixed(0)}%)',
      );
    }

    debugPrint('[Recognition] No MB match above threshold $minScore');
    return null;
  }

  Future<Album?> _searchByBarcode(String barcode) async {
    try {
      final mbRaw = await _musicBrainz.searchByBarcode(barcode);
      if (mbRaw.isNotEmpty) {
        final first = mbRaw.first;
        return Album(
          id: const Uuid().v4(),
          title: first['title']?.toString() ?? 'Unknown',
          artist: first['artist-credit']?[0]?['name']?.toString() ?? 'Unknown',
          releaseYear: _parseYear(first['date']?.toString()),
          dateAdded: DateTime.now(),
          musicBrainzId: first['id']?.toString(),
          barcode: barcode,
          recognitionConfidence: 0.8,
        );
      }
    } catch (_) {}
    try {
      final results = await _discogs.searchRelease(barcode);
      if (results.isNotEmpty) return results.first;
    } catch (_) {}
    return null;
  }

  Future<List<Album>> searchByQuery(String query) async {
    final results = <Album>[];
    try {
      final mbRaw = await _musicBrainz.searchRelease(query: query);
      for (final r in mbRaw) {
        results.add(Album(
          id: const Uuid().v4(),
          title: r['title']?.toString() ?? 'Unknown',
          artist: r['artist-credit']?[0]?['name']?.toString() ?? 'Unknown',
          releaseYear: _parseYear(r['date']?.toString()),
          dateAdded: DateTime.now(),
          musicBrainzId: r['id']?.toString(),
          recognitionConfidence: 0.5,
        ));
      }
    } catch (_) {}
    if (results.isEmpty) {
      try { results.addAll(await _discogs.searchRelease(query)); } catch (_) {}
    }
    return results;
  }

  Future<void> indexAlbum(Album album) async {
    await _offlineService?.indexAlbum(album);
  }
}

/// Internal class to track match candidates during scoring.
class _MatchCandidate {
  final String artist;
  final String title;
  final String? date;
  final String? mbid;
  final double score;
  final String query;

  _MatchCandidate({
    required this.artist,
    required this.title,
    this.date,
    this.mbid,
    required this.score,
    required this.query,
  });
}
