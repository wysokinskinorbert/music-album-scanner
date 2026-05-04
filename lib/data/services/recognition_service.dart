import '../../core/network/connectivity_service.dart';
import 'api/musicbrainz_service.dart';
import 'api/discogs_service.dart';
import 'ml/text_extraction_service.dart';
import 'ml/image_labeling_service.dart';
import 'ml/barcode_scanning_service.dart';
import 'offline/offline_recognition_service.dart';
import '../models/album_model.dart';
import '../models/recognition_result.dart';
import 'package:logger/logger.dart';

/// Multi-strategy album recognition orchestrator.
class RecognitionService {
  final MusicBrainzService _musicBrainz;
  final DiscogsService _discogs;
  final TextExtractionService _textExtractor;
  final ImageLabelingService _imageLabeler;
  final BarcodeScanningService _barcodeScanner;
  final OfflineRecognitionService? _offlineService;
  final ConnectivityService _connectivity;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  RecognitionService({
    required MusicBrainzService musicBrainz,
    required DiscogsService discogs,
    required TextExtractionService textExtractor,
    required ImageLabelingService imageLabeler,
    required BarcodeScanningService barcodeScanner,
    required ConnectivityService connectivity,
    OfflineRecognitionService? offlineService,
  })  : _musicBrainz = musicBrainz,
        _discogs = discogs,
        _textExtractor = textExtractor,
        _imageLabeler = imageLabeler,
        _barcodeScanner = barcodeScanner,
        _connectivity = connectivity,
        _offlineService = offlineService;

  /// Full recognition pipeline with step-by-step progress.
  Future<RecognitionResult> recognize(
    String imagePath, {
    void Function(String step, int completed, int total)? onProgress,
  }) async {
    const totalSteps = 5;
    int completed = 0;
    final pipelineLog = <String>[];
    String? extractedText;

    void progress(String step) {
      pipelineLog.add(step);
      onProgress?.call(step, completed, totalSteps);
    }

    try {
      // STEP 1: Barcode Scan
      progress('Scanning for barcode...');
      final barcodeResult = await _barcodeScanner.scanImage(imagePath);

      if (barcodeResult.hasBarcode && barcodeResult.isAlbumBarcode) {
        completed++;
        progress('Barcode found: ${barcodeResult.barcode}');

        if (_connectivity.isOnline) {
          final mbResults = await _musicBrainz.searchByBarcode(barcodeResult.barcode);
          if (mbResults.isNotEmpty) {
            final parsed = _musicBrainz.parseRelease(mbResults.first);
            final album = _parsedToAlbum(parsed, userPhotoPath: imagePath);
            progress('MusicBrainz barcode match!');
            return _success(
              album: album,
              confidence: 0.95,
              source: 'Barcode',
              pipelineSummary: pipelineLog.join(' -> '),
              extractedText: null,
            );
          }
        }
      }
      completed++;

      if (!_connectivity.isOnline) {
        progress('Offline mode - trying local recognition...');
        return await _tryOfflineRecognition(
          imagePath, pipelineLog, extractedText,
        );
      }

      // STEP 2: OCR Text Extraction + MusicBrainz
      progress('Extracting text from cover...');
      final textResult = await _textExtractor.extractText(imagePath);
      extractedText = textResult.rawText;

      if (textResult.hasText) {
        final queries = _textExtractor.generateSearchQueries(textResult);
        progress('OCR: found ${queries.length} queries');

        for (final query in queries) {
          final mbResults = await _musicBrainz.searchRelease(query: query);
          if (mbResults.isNotEmpty) {
            completed++;
            final parsed = _musicBrainz.parseRelease(mbResults.first);
            final album = _parsedToAlbum(parsed, userPhotoPath: imagePath);
            final confidence = mbResults.length == 1 ? 0.85 : 0.80;

            progress('MusicBrainz match: ${album.title}');
            return _success(
              album: album,
              confidence: confidence,
              source: 'MusicBrainz (OCR)',
              pipelineSummary: pipelineLog.join(' -> '),
              extractedText: extractedText,
            );
          }
        }
      }
      completed++;

      // STEP 3: Discogs Fallback
      progress('Searching Discogs...');
      final discogsQueries = textResult.hasText
          ? _textExtractor.generateSearchQueries(textResult)
          : <String>[];

      for (final query in discogsQueries.take(2)) {
        final discogsResults = await _discogs.search(query: query);
        if (discogsResults.isNotEmpty) {
          completed++;
          final parsed = _discogs.parseRelease(discogsResults.first);
          final album = _parsedToAlbum(parsed, userPhotoPath: imagePath);

          progress('Discogs match: ${album.title}');
          return _success(
            album: album,
            confidence: 0.75,
            source: 'Discogs (OCR)',
            pipelineSummary: pipelineLog.join(' -> '),
            extractedText: extractedText,
          );
        }
      }
      completed++;

      // STEP 4: Visual Analysis
      progress('Analyzing cover artwork...');
      final coverAnalysis = await _imageLabeler.analyzeCover(imagePath);

      if (coverAnalysis.labels.isNotEmpty) {
        final visualQuery = coverAnalysis.labelTexts.take(3).join(' ');
        progress('Visual: "$visualQuery"');

        final mbResults = await _musicBrainz.searchRelease(query: visualQuery);
        if (mbResults.isNotEmpty) {
          final parsed = _musicBrainz.parseRelease(mbResults.first);
          final album = _parsedToAlbum(parsed, userPhotoPath: imagePath);
          progress('Visual match: ${album.title}');
          return _success(
            album: album,
            confidence: 0.60,
            source: 'Visual Analysis',
            pipelineSummary: pipelineLog.join(' -> '),
            extractedText: extractedText,
          );
        }
      }
      completed++;

      // STEP 5: Offline
      if (_offlineService != null && _offlineService.isAvailable) {
        progress('Trying offline recognition...');
        final offlineResult = await _offlineService.recognize(imagePath);

        if (offlineResult.recognized && offlineResult.confidence >= 0.50) {
          final album = offlineResult.toAlbum(photoPath: imagePath);
          progress('Offline match: ${album.title}');
          return _success(
            album: album,
            confidence: offlineResult.confidence,
            source: 'Offline (${offlineResult.method})',
            pipelineSummary: pipelineLog.join(' -> '),
            extractedText: extractedText,
          );
        }
      }

      // ALL FAILED
      progress('No match found');
      return RecognitionResult(
        state: RecognitionState.failed,
        message: 'Could not identify this album. Try a clearer photo or use manual search.',
        pipelineSummary: pipelineLog.join(' -> '),
        extractedText: extractedText,
      );
    } catch (e) {
      _logger.e('Recognition pipeline error: $e');
      return RecognitionResult(
        state: RecognitionState.error,
        message: 'Recognition error: $e',
        pipelineSummary: pipelineLog.join(' -> '),
        extractedText: extractedText,
      );
    }
  }

  /// Text-based search for manual lookup.
  Future<RecognitionResult> searchByQuery(String artist, String albumTitle) async {
    try {
      final query = '$artist $albumTitle';

      // Try MusicBrainz first
      final mbResults = await _musicBrainz.searchRelease(query: query);
      if (mbResults.isNotEmpty) {
        final parsed = _musicBrainz.parseRelease(mbResults.first);
        final album = _parsedToAlbum(parsed);
        return RecognitionResult(
          state: RecognitionState.success,
          album: album,
          confidence: 0.85,
          source: 'MusicBrainz',
        );
      }

      // Try Discogs
      final discogsResults = await _discogs.search(query: query);
      if (discogsResults.isNotEmpty) {
        final parsed = _discogs.parseRelease(discogsResults.first);
        final album = _parsedToAlbum(parsed);
        return RecognitionResult(
          state: RecognitionState.success,
          album: album,
          confidence: 0.75,
          source: 'Discogs',
        );
      }

      return RecognitionResult(
        state: RecognitionState.failed,
        message: 'No results found for "$artist - $albumTitle"',
      );
    } catch (e) {
      return RecognitionResult(
        state: RecognitionState.error,
        message: 'Search error: $e',
      );
    }
  }

  /// Offline-only recognition path.
  Future<RecognitionResult> _tryOfflineRecognition(
    String imagePath,
    List<String> pipelineLog,
    String? extractedText,
  ) async {
    if (_offlineService == null || !_offlineService.isAvailable) {
      return RecognitionResult(
        state: RecognitionState.failed,
        message: 'No internet and offline model not available.',
        pipelineSummary: pipelineLog.join(' -> '),
        extractedText: extractedText,
      );
    }

    final result = await _offlineService.recognize(imagePath);

    if (result.recognized) {
      final album = result.toAlbum(photoPath: imagePath);
      return _success(
        album: album,
        confidence: result.confidence,
        source: 'Offline (${result.method})',
        pipelineSummary: pipelineLog.join(' -> '),
        extractedText: extractedText,
      );
    }

    return RecognitionResult(
      state: RecognitionState.failed,
      message: 'Offline recognition could not identify this album.',
      pipelineSummary: pipelineLog.join(' -> '),
      extractedText: extractedText,
    );
  }

  RecognitionResult _success({
    required Album album,
    required double confidence,
    required String source,
    required String pipelineSummary,
    String? extractedText,
  }) {
    if (_offlineService != null && album.userPhotoPath != null) {
      _offlineService.addToIndex(album);
    }

    return RecognitionResult(
      state: RecognitionState.success,
      album: album,
      confidence: confidence,
      source: source,
      pipelineSummary: pipelineSummary,
      extractedText: extractedText,
    );
  }

  /// Convert parsed API data map to Album model.
  Album _parsedToAlbum(Map<String, dynamic> data, {String? userPhotoPath}) {
    return Album(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: data['title'] as String? ?? 'Unknown',
      artist: data['artist'] as String? ?? 'Unknown',
      releaseYear: data['releaseYear'] as int?,
      label: data['label'] as String?,
      genre: data['genre'] as String?,
      tracklist: (data['tracklist'] as List<dynamic>?)
          ?.map((t) => t.toString())
          .toList() ?? [],
      coverArtUrl: data['coverArtUrl'] as String?,
      userPhotoPath: userPhotoPath,
      dateAdded: DateTime.now(),
      musicBrainzId: data['musicBrainzId'] as String?,
      discogsId: data['discogsId']?.toString(),
      country: data['country'] as String?,
    );
  }
}
