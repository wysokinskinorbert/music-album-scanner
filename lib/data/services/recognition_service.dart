import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/album_model.dart';
import '../models/recognition_result.dart';
import 'api/musicbrainz_service.dart';
import 'api/discogs_service.dart';
import 'ml/barcode_scanning_service.dart';
import 'offline/offline_recognition_service.dart';
import 'ml/tflite_inference_service.dart';
import '../../../core/network/api_client.dart';

/// Main recognition pipeline service.
class RecognitionService {
  final ApiClient _apiClient;
  final MusicBrainzService _musicBrainz;
  final DiscogsService _discogs;
  final BarcodeScanningService _barcodeService;
  final TfliteInferenceService? _tfliteService;
  final OfflineRecognitionService? _offlineService;

  RecognitionService({
    required ApiClient apiClient,
    MusicBrainzService? musicBrainz,
    DiscogsService? discogs,
    BarcodeScanningService? barcodeService,
    TfliteInferenceService? tfliteService,
    OfflineRecognitionService? offlineService,
  })  : _apiClient = apiClient,
        _musicBrainz = musicBrainz ?? MusicBrainzService(apiClient),
        _discogs = discogs ?? DiscogsService(apiClient),
        _barcodeService = barcodeService ?? BarcodeScanningService(),
        _tfliteService = tfliteService,
        _offlineService = offlineService;

  /// Main recognition pipeline
  Future<RecognitionResult> recognizeFromImage(String imagePath) async {
    try {
      // Step 1: Try barcode scanning
      final barcode = await _barcodeService.scanBarcodeFromFile(imagePath);
      if (barcode != null && barcode.isNotEmpty) {
        final album = await _searchByBarcode(barcode);
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

      // Step 2: Try offline/TFLite
      if (_offlineService != null) {
        try {
          final offlineResult = await _offlineService!.recognize(imagePath);
          if (offlineResult != null && offlineResult.confidence >= 0.6) {
            final album = Album(
              id: const Uuid().v4(),
              title: offlineResult.title,
              artist: offlineResult.artist,
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

      // Step 3: ML classification hints
      String? searchQuery;
      if (_tfliteService != null && _tfliteService!.isModelLoaded) {
        try {
          final labels = await _tfliteService!.classify(imagePath);
          if (labels.isNotEmpty) searchQuery = labels.first.key;
        } catch (_) {}
      }

      // Step 4: MusicBrainz
      if (searchQuery != null) {
        final mbResults = await _musicBrainz.searchRelease(searchQuery);
        if (mbResults.isNotEmpty) {
          return RecognitionResult(
            state: RecognitionState.success,
            album: mbResults.first,
            confidence: mbResults.first.recognitionConfidence,
            source: 'online',
          );
        }
      }

      // Step 5: Discogs fallback
      if (searchQuery != null) {
        final discogsResults = await _discogs.searchRelease(searchQuery);
        if (discogsResults.isNotEmpty) {
          return RecognitionResult(
            state: RecognitionState.success,
            album: discogsResults.first,
            confidence: discogsResults.first.recognitionConfidence,
            source: 'online',
          );
        }
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
      final results = await _musicBrainz.searchRelease('barcode:$barcode');
      if (results.isNotEmpty) return results.first;
    } catch (_) {}
    try {
      final results = await _discogs.searchRelease(barcode);
      if (results.isNotEmpty) return results.first;
    } catch (_) {}
    return null;
  }

  Future<List<Album>> searchByQuery(String query) async {
    final results = <Album>[];
    try { results.addAll(await _musicBrainz.searchRelease(query)); } catch (_) {}
    if (results.isEmpty) {
      try { results.addAll(await _discogs.searchRelease(query)); } catch (_) {}
    }
    return results;
  }

  Future<void> indexAlbum(Album album) async {
    await _offlineService?.indexAlbum(album);
  }
}
