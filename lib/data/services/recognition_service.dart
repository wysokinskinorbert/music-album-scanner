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
///
/// Pipeline order (stops at first confident match):
///   1. Barcode scan -> MusicBrainz direct lookup (95%)
///   2. OCR text -> MusicBrainz search (85%)
///   3. OCR text -> Discogs fallback (75%)
///   4. Visual labels -> context-assisted search (60%)
///   5. Offline TFLite model / embedding match (50-80%)
///   6. Fail -> return best partial result
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
    String? coverType;

    void progress(String step) {
      pipelineLog.add(step);
      onProgress?.call(step, completed, totalSteps);
    }

    try {
      // ==========================================
      // STEP 1: Barcode Scan
      // ==========================================
      progress('Scanning for barcode...');
      final barcodeResult = await _barcodeScanner.scanFromFile(imagePath);

      if (barcodeResult != null && barcodeResult.isAlbumBarcode) {
        completed++;
        progress('Barcode found: \${barcodeResult.displayValue}');

        if (await _connectivity.isOnline) {
          final album = await _musicBrainz.searchByBarcode(barcodeResult.displayValue);
          if (album != null) {
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

      // If offline, skip to offline recognition
      if (!await _connectivity.isOnline) {
        progress('Offline mode - trying local recognition...');
        return await _tryOfflineRecognition(
          imagePath, pipelineLog, extractedText,
        );
      }

      // ==========================================
      // STEP 2: OCR Text Extraction + MusicBrainz
      // ==========================================
      progress('Extracting text from cover...');
      final textResult = await _textExtractor.extractTextFromFile(imagePath);
      extractedText = textResult?.fullText;

      if (textResult != null && textResult.searchQueries.isNotEmpty) {
        progress('OCR: found \${textResult.searchQueries.length} queries');

        for (final query in textResult.searchQueries) {
          final mbResults = await _musicBrainz.searchRelease(query);
          if (mbResults.isNotEmpty) {
            completed++;
            final best = mbResults.first;
            final confidence = mbResults.length == 1 ? 0.85 : 0.80;

            // Enrich with full release details
            Album? enriched;
            if (best.musicBrainzId != null) {
              enriched = await _musicBrainz.getReleaseDetails(
                best.musicBrainzId!,
              );
            }

            progress('MusicBrainz match: \${best.title}');
            return _success(
              album: enriched ?? best,
              confidence: confidence,
              source: 'MusicBrainz (OCR)',
              pipelineSummary: pipelineLog.join(' -> '),
              extractedText: extractedText,
            );
          }
        }
      }
      completed++;

      // ==========================================
      // STEP 3: Discogs Fallback
      // ==========================================
      progress('Searching Discogs...');
      final discogsQueries = textResult?.searchQueries ?? [];

      for (final query in discogsQueries.take(2)) {
        final discogsResults = await _discogs.searchRelease(query);
        if (discogsResults.isNotEmpty) {
          completed++;
          final best = discogsResults.first;

          progress('Discogs match: \${best.title}');
          return _success(
            album: best,
            confidence: 0.75,
            source: 'Discogs (OCR)',
            pipelineSummary: pipelineLog.join(' -> '),
            extractedText: extractedText,
          );
        }
      }
      completed++;

      // ==========================================
      // STEP 4: Visual Analysis
      // ==========================================
      progress('Analyzing cover artwork...');
      final labelResult = await _imageLabeler.analyzeFromFile(imagePath);
      coverType = labelResult.coverType;

      if (labelResult.labels.isNotEmpty) {
        // Build a search query from visual labels
        final visualQuery = labelResult.labels
            .take(3)
            .map((l) => l.label)
            .join(' ');
        progress('Visual: "$visualQuery"');

        // Try MusicBrainz with visual context
        final mbResults = await _musicBrainz.searchRelease(visualQuery);
        if (mbResults.isNotEmpty) {
          final best = mbResults.first;
          progress('Visual match: \${best.title}');
          return _success(
            album: best,
            confidence: 0.60,
            source: 'Visual Analysis',
            pipelineSummary: pipelineLog.join(' -> '),
            extractedText: extractedText,
          );
        }
      }
      completed++;

      // ==========================================
      // STEP 5: Offline TFLite / Embedding Match
      // ==========================================
      if (_offlineService != null && _offlineService.isAvailable) {
        progress('Trying offline recognition...');
        final offlineResult = await _offlineService.recognize(imagePath);

        if (offlineResult.recognized && offlineResult.confidence >= 0.50) {
          final album = offlineResult.toAlbum(photoPath: imagePath);
          progress('Offline match: \${album.title}');
          return _success(
            album: album,
            confidence: offlineResult.confidence,
            source: 'Offline (\${offlineResult.method})',
            pipelineSummary: pipelineLog.join(' -> '),
            extractedText: extractedText,
          );
        }
      }

      // ==========================================
      // ALL FAILED
      // ==========================================
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
        message: 'Recognition error: \$e',
        pipelineSummary: pipelineLog.join(' -> '),
        extractedText: extractedText,
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
        message: 'No internet and offline model not available. Download the model in Settings first.',
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
        source: 'Offline (\${result.method})',
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
    // If offline service is available, add to embedding index
    if (_offlineService != null && album.userPhotoPath != null) {
      _offlineService.addToIndex(album); // Fire-and-forget
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
}
