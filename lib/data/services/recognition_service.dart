import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/album_model.dart';
import '../models/recognition_result.dart';
import 'api/musicbrainz_service.dart';
import 'api/discogs_service.dart';
import 'ml/barcode_scanning_service.dart';
import 'ml/text_extraction_service.dart';
import 'ml/image_labeling_service.dart';
import 'offline/offline_recognition_service.dart';
import 'ml/tflite_inference_service.dart';
import '../../core/network/api_client.dart';

/// Main recognition pipeline service.
class RecognitionService {
  final ApiClient _apiClient;
  final MusicBrainzService _musicBrainz;
  final DiscogsService _discogs;
  final BarcodeScanningService _barcodeService;
  final TfliteInferenceService? _tfliteService;
  final OfflineRecognitionService? _offlineService;
  final TextExtractionService? _textExtraction;
  final ImageLabelingService? _imageLabeler;

  RecognitionService({
    required ApiClient apiClient,
    MusicBrainzService? musicBrainz,
    DiscogsService? discogs,
    BarcodeScanningService? barcodeService,
    TfliteInferenceService? tfliteService,
    OfflineRecognitionService? offlineService,
    TextExtractionService? textExtraction,
    ImageLabelingService? imageLabeler,
  })  : _apiClient = apiClient,
        _musicBrainz = musicBrainz ?? MusicBrainzService(ApiClient()),
        _discogs = discogs ?? DiscogsService(),
        _barcodeService = barcodeService ?? BarcodeScanningService(),
        _tfliteService = tfliteService,
        _offlineService = offlineService,
        _textExtraction = textExtraction,
        _imageLabeler = imageLabeler;

  /// Main recognition pipeline
  Future<RecognitionResult> recognizeFromImage(String imagePath) async {
    debugPrint('══════════════════════════════════════════');
    debugPrint('[Recognition] START recognizeFromImage path="$imagePath"');
    debugPrint('══════════════════════════════════════════');

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

      // Step 2: OCR text extraction
      debugPrint('[Recognition] Step 2: OCR text extraction...');
      String? searchQuery;
      if (_textExtraction != null) {
        try {
          final extracted = await _textExtraction!.extractText(imagePath);
          debugPrint('[Recognition] OCR rawText: "${extracted.rawText}"');
          debugPrint('[Recognition] OCR lines: ${extracted.lines}');
          debugPrint('[Recognition] OCR hasText: ${extracted.hasText}, blocks: ${extracted.blockCount}');
          if (extracted.hasText) {
            final queries = _textExtraction!.generateSearchQueries(extracted);
            debugPrint('[Recognition] OCR generated queries: $queries');
            if (queries.isNotEmpty) {
              searchQuery = queries.first;
            }
          }
        } catch (e) {
          debugPrint('[Recognition] OCR ERROR: $e');
        }
      } else {
        debugPrint('[Recognition] TextExtraction is NULL');
      }

      // Step 3: Image labeling
      debugPrint('[Recognition] Step 3: Image labeling...');
      if (searchQuery == null && _imageLabeler != null) {
        try {
          final analysis = await _imageLabeler!.analyzeCover(imagePath);
          debugPrint('[Recognition] Labels: ${analysis.labelTexts}');
          debugPrint('[Recognition] CoverType: ${analysis.coverType}, genres: ${analysis.detectedGenres}');
          if (analysis.labels.isNotEmpty) {
            final bestLabel = analysis.labels.reduce(
              (a, b) => a.confidence > b.confidence ? a : b,
            );
            searchQuery = bestLabel.label;
            debugPrint('[Recognition] Best label: "${bestLabel.label}" (${(bestLabel.confidence * 100).toStringAsFixed(0)}%)');
          }
        } catch (e) {
          debugPrint('[Recognition] ImageLabeler ERROR: $e');
        }
      } else if (_imageLabeler == null) {
        debugPrint('[Recognition] ImageLabeler is NULL');
      }

      // Step 4: TFLite
      debugPrint('[Recognition] Step 4: TFLite classification...');
      if (searchQuery == null && _tfliteService != null) {
        debugPrint('[Recognition] TFLite model loaded: ${_tfliteService!.isModelLoaded}');
        if (_tfliteService!.isModelLoaded) {
          try {
            final labels = await _tfliteService!.classify(imagePath);
            debugPrint('[Recognition] TFLite labels: $labels');
            if (labels.isNotEmpty) searchQuery = labels.first.key;
          } catch (e) {
            debugPrint('[Recognition] TFLite ERROR: $e');
          }
        }
      } else if (_tfliteService == null) {
        debugPrint('[Recognition] TFLite is NULL');
      }

      // Step 5: Offline
      debugPrint('[Recognition] Step 5: Offline recognition...');
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
      } else {
        debugPrint('[Recognition] OfflineService is NULL');
      }

      // Step 6: MusicBrainz search
      debugPrint('[Recognition] Step 6: MusicBrainz search, searchQuery="$searchQuery"');
      if (searchQuery != null) {
        List<String> allQueries = [];
        if (_textExtraction != null) {
          try {
            final extracted = await _textExtraction!.extractText(imagePath);
            if (extracted.hasText) {
              allQueries = _textExtraction!.generateSearchQueries(extracted);
              debugPrint('[Recognition] All OCR queries for MB: $allQueries');
            }
          } catch (e) {
            debugPrint('[Recognition] OCR re-extract ERROR: $e');
          }
        }
        if (allQueries.isEmpty) {
          allQueries = [searchQuery];
        }

        for (final query in allQueries) {
          debugPrint('[Recognition] Trying MusicBrainz query: "$query"');
          try {
            final mbRaw = await _musicBrainz.searchRelease(query: query);
            if (mbRaw.isNotEmpty) {
              final first = mbRaw.first;
              debugPrint('[Recognition] MB hit: ${first['title']} by ${first['artist-credit']?[0]?['name']}');
              final album = Album(
                id: const Uuid().v4(),
                title: first['title']?.toString() ?? 'Unknown',
                artist: first['artist-credit']?[0]?['name']?.toString() ??
                    'Unknown',
                releaseYear: int.tryParse(
                    first['date']?.toString().substring(0, 4) ?? ''),
                dateAdded: DateTime.now(),
                musicBrainzId: first['id']?.toString(),
                recognitionConfidence: 0.5,
                userPhotoPath: imagePath,
              );
              return RecognitionResult(
                state: RecognitionState.success,
                album: album,
                confidence: 0.5,
                source: 'online',
              );
            }
          } catch (e) {
            debugPrint('[Recognition] MusicBrainz query "$query" ERROR: $e');
          }
        }
      } else {
        debugPrint('[Recognition] No searchQuery -- skipping MusicBrainz');
      }

      // Step 7: Discogs fallback
      debugPrint('[Recognition] Step 7: Discogs fallback, searchQuery="$searchQuery"');
      if (searchQuery != null) {
        try {
          final discogsResults = await _discogs.searchRelease(searchQuery);
          debugPrint('[Recognition] Discogs results: ${discogsResults.length}');
          if (discogsResults.isNotEmpty) {
            return RecognitionResult(
              state: RecognitionState.success,
              album: discogsResults.first,
              confidence: discogsResults.first.recognitionConfidence,
              source: 'online',
            );
          }
        } catch (e) {
          debugPrint('[Recognition] Discogs ERROR: $e');
        }
      }

      debugPrint('[Recognition] ALL STEPS FAILED - returning failure');
      return RecognitionResult(
        state: RecognitionState.failed,
        message: 'Could not recognize album. Try taking a clearer photo.',
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

  Future<Album?> _searchByBarcode(String barcode) async {
    try {
      final mbRaw = await _musicBrainz.searchByBarcode(barcode);
      if (mbRaw.isNotEmpty) {
        final first = mbRaw.first;
        return Album(
          id: const Uuid().v4(),
          title: first['title']?.toString() ?? 'Unknown',
          artist: first['artist-credit']?[0]?['name']?.toString() ?? 'Unknown',
          releaseYear: int.tryParse(first['date']?.toString().substring(0, 4) ?? ''),
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
          releaseYear: int.tryParse(r['date']?.toString().substring(0, 4) ?? ''),
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
