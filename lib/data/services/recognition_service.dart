import 'dart:io';
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
    try {
      // Step 1: Try barcode scanning
      final barcodeResult = await _barcodeService.scanImage(imagePath);
      if (barcodeResult.barcode != null && barcodeResult.barcode!.isNotEmpty) {
        final album = await _searchByBarcode(barcodeResult.barcode!);
        if (album != null) {
          return RecognitionResult(
            state: RecognitionState.success,
            album: album,
            confidence: album.recognitionConfidence,
            source: 'barcode',
            message: 'Found via barcode',
          );
        }
      }

      // Step 2: OCR text extraction -- primary path for covers with text
      String? searchQuery;
      if (_textExtraction != null) {
        try {
          final extracted = await _textExtraction!.extractText(imagePath);
          if (extracted.hasText) {
            final queries = _textExtraction!.generateSearchQueries(extracted);
            if (queries.isNotEmpty) {
              searchQuery = queries.first;
            }
          }
        } catch (_) {}
      }

      // Step 3: Image labeling -- fallback when OCR finds no text
      if (searchQuery == null && _imageLabeler != null) {
        try {
          final analysis = await _imageLabeler!.analyzeCover(imagePath);
          if (analysis.labels.isNotEmpty) {
            // Use highest-confidence label as search query
            final bestLabel = analysis.labels.reduce(
              (a, b) => a.confidence > b.confidence ? a : b,
            );
            searchQuery = bestLabel.label;
          }
        } catch (_) {}
      }

      // Step 4: TFLite classification -- additional fallback
      if (searchQuery == null &&
          _tfliteService != null &&
          _tfliteService!.isModelLoaded) {
        try {
          final labels = await _tfliteService!.classify(imagePath);
          if (labels.isNotEmpty) searchQuery = labels.first.key;
        } catch (_) {}
      }

      // Step 5: Offline recognition
      if (_offlineService != null) {
        try {
          final offlineResult = await _offlineService!.recognize(imagePath);
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
        } catch (_) {}
      }

      // Step 6: MusicBrainz search with best available query
      if (searchQuery != null) {
        // Try each OCR query strategy before falling back
        List<String> allQueries = [];
        if (_textExtraction != null) {
          try {
            final extracted = await _textExtraction!.extractText(imagePath);
            if (extracted.hasText) {
              allQueries = _textExtraction!.generateSearchQueries(extracted);
            }
          } catch (_) {}
        }
        if (allQueries.isEmpty) {
          allQueries = [searchQuery];
        }

        for (final query in allQueries) {
          try {
            final mbRaw = await _musicBrainz.searchRelease(query: query);
            if (mbRaw.isNotEmpty) {
              final first = mbRaw.first;
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
          } catch (_) {}
        }
      }

      // Step 7: Discogs fallback
      if (searchQuery != null) {
        try {
          final discogsResults = await _discogs.searchRelease(searchQuery);
          if (discogsResults.isNotEmpty) {
            return RecognitionResult(
              state: RecognitionState.success,
              album: discogsResults.first,
              confidence: discogsResults.first.recognitionConfidence,
              source: 'online',
            );
          }
        } catch (_) {}
      }

      return RecognitionResult(
        state: RecognitionState.failed,
        message: 'Could not recognize album. Try taking a clearer photo.',
      );
    } catch (e) {
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
