import '../../core/network/api_client.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/constants/app_constants.dart';
import '../models/recognition_result.dart';
import 'api/musicbrainz_service.dart';
import 'api/discogs_service.dart';
import 'ml/offline_recognition_service.dart';

/// Orchestrates online and offline album recognition.
class RecognitionService {
  final MusicBrainzService _musicBrainz;
  final DiscogsService _discogs;
  final OfflineRecognitionService _offline;
  final ConnectivityService _connectivity;

  RecognitionService({
    required ApiClient apiClient,
    required ConnectivityService connectivity,
  })  : _musicBrainz = MusicBrainzService(apiClient),
        _discogs = DiscogsService(apiClient),
        _offline = OfflineRecognitionService(),
        _connectivity = connectivity;

  /// Main recognition pipeline.
  /// Tries online first, falls back to offline model.
  Future<RecognitionResult> recognizeAlbum(String imagePath) async {
    // Step 1: Try online recognition
    if (_connectivity.isOnline) {
      final result = await _recognizeOnline(imagePath);
      if (result.isSuccess && result.isHighConfidence) {
        return result;
      }
    }

    // Step 2: Try offline model
    if (_offline.isModelLoaded) {
      final offlineResult = await _recognizeOffline(imagePath);
      if (offlineResult != null && offlineResult.confidence >= AppConstants.confidenceThreshold) {
        return offlineResult;
      }
    }

    return const RecognitionResult(
      confidence: 0.0,
      source: 'none',
      errorMessage: 'Could not recognize album. Try a clearer photo.',
    );
  }

  Future<RecognitionResult> _recognizeOnline(String imagePath) async {
    try {
      // Use Google ML Kit for image labeling to extract text/visual features
      // Then query MusicBrainz with extracted info
      // This is a placeholder for the full pipeline

      // TODO: Integrate Google ML Kit image labeling
      // TODO: Extract text from cover (OCR)
      // TODO: Use extracted text to query MusicBrainz

      return const RecognitionResult(
        confidence: 0.0,
        source: 'online',
      );
    } catch (e) {
      return RecognitionResult(
        confidence: 0.0,
        source: 'online',
        errorMessage: e.toString(),
      );
    }
  }

  Future<RecognitionResult?> _recognizeOffline(String imagePath) async {
    final result = await _offline.recognize(imagePath);
    if (result == null) return null;

    return RecognitionResult(
      confidence: result.confidence,
      source: 'offline',
    );
  }

  /// Search by known artist + album (manual input or partial match).
  Future<RecognitionResult> searchByQuery(String artist, String album) async {
    try {
      final query = '${artist.trim()} AND ${album.trim()}';
      final releases = await _musicBrainz.searchRelease(query: query, limit: 3);

      if (releases.isEmpty) {
        // Fallback to Discogs
        final discogsResults = await _discogs.search(query: '$artist $album');
        if (discogsResults.isEmpty) {
          return const RecognitionResult(
            confidence: 0.0,
            source: 'online',
            errorMessage: 'No results found',
          );
        }
        final parsed = _discogs.parseRelease(discogsResults[0]);
        return RecognitionResult(
          albumTitle: parsed['title'],
          artist: parsed['artist'],
          confidence: 0.8,
          source: 'online',
          rawApiData: parsed,
        );
      }

      final parsed = _musicBrainz.parseRelease(releases[0]);
      return RecognitionResult(
        albumTitle: parsed['title'],
        artist: parsed['artist'],
        confidence: 0.9,
        source: 'online',
        rawApiData: parsed,
      );
    } catch (e) {
      return RecognitionResult(
        confidence: 0.0,
        source: 'online',
        errorMessage: e.toString(),
      );
    }
  }

  /// Load the offline model for later use.
  Future<bool> loadOfflineModel() => _offline.loadModel();

  void dispose() {
    _offline.dispose();
  }
}
