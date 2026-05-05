import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_album_scanner/data/models/album_model.dart';
import 'package:music_album_scanner/data/models/recognition_result.dart';
import 'package:music_album_scanner/data/repositories/album_repository.dart';
import 'package:music_album_scanner/features/scan_result/bloc/scan_result_bloc.dart';
import 'package:music_album_scanner/features/scan_result/bloc/scan_result_event.dart';
import 'package:music_album_scanner/features/scan_result/bloc/scan_result_state.dart';

import '../../../helpers/test_helpers.dart';

// ---------------------------------------------------------------
// Stubs for types referenced by ScanResultBloc that are not yet
// defined in the main codebase.  The bloc imports these implicitly;
// the test must provide them so that the mock can return valid data.
// ---------------------------------------------------------------

/// Simple text extraction result returned by the pipeline.
class ExtractedTextResult {
  final String rawText;
  const ExtractedTextResult(this.rawText);
}

/// Represents the aggregated output of the multi-step recognition
/// pipeline.  The ScanResultBloc consumes this type.
class RecognitionPipelineResult {
  final RecognitionResult bestResult;
  final String pipelineSummary;
  final ExtractedTextResult? extractedText;
  final int stepsAttempted;
  final int stepsSucceeded;

  const RecognitionPipelineResult({
    required this.bestResult,
    required this.pipelineSummary,
    this.extractedText,
    this.stepsAttempted = 0,
    this.stepsSucceeded = 0,
  });
}

/// Extension on RecognitionService to expose the methods that
/// ScanResultBloc actually calls.  In production code these would
/// exist on the service; here we just declare the interface so that
/// mocktail can stub them.
/// We achieve this by mocking a thin abstract class.
abstract class RecognitionServicePort {
  Future<RecognitionPipelineResult> recognizeAlbum(String imagePath);
  Future<RecognitionResult> searchByQuery(String artist, String album);
}

// --- Mocks ---
class MockRecognitionService extends Mock implements RecognitionServicePort {}

class MockAlbumRepository extends Mock implements AlbumRepository {}

// Fakes for fallback values
class FakeRecognitionResult extends Fake implements RecognitionResult {}
class FakeAlbum extends Fake implements Album {}

void main() {
  late MockRecognitionService mockRecognition;
  late MockAlbumRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeRecognitionResult());
  });

  setUp(() {
    mockRecognition = MockRecognitionService();
    mockRepository = MockAlbumRepository();
  });

  ScanResultBloc createBloc() => ScanResultBloc(
        recognition: mockRecognition,
        repository: mockRepository,
      );

  // ---------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------
  group('initial state', () {
    test('initial state is ScanResultInitial', () {
      final bloc = createBloc();
      expect(bloc.state, isA<ScanResultInitial>());
    });
  });

  // ---------------------------------------------------------------
  // StartRecognition
  // ---------------------------------------------------------------
  group('StartRecognition', () {
    blocTest<ScanResultBloc, ScanResultState>(
      'emits [ScanResultProcessing, ScanResultSuccess] on successful recognition',
      build: () {
        when(() => mockRecognition.recognizeAlbum(any()))
            .thenAnswer((_) async => RecognitionPipelineResult(
                  bestResult: RecognitionResultFactory.create(
                    albumTitle: 'Kind of Blue',
                    artist: 'Miles Davis',
                    confidence: 0.95,
                    source: 'barcode',
                    rawApiData: {
                      'title': 'Kind of Blue',
                      'artist': 'Miles Davis',
                      'releaseYear': 1959,
                    },
                  ),
                  pipelineSummary: 'Barcode -> MusicBrainz',
                  stepsAttempted: 2,
                  stepsSucceeded: 2,
                ));
        return createBloc();
      },
      act: (bloc) => bloc.add(const StartRecognition('/tmp/photo.jpg')),
      expect: () => [
        isA<ScanResultProcessing>().having(
          (s) => s.currentStep,
          'currentStep',
          'Scanning barcode...',
        ),
        isA<ScanResultSuccess>()
            .having((s) => s.album.title, 'title', 'Kind of Blue')
            .having((s) => s.confidence, 'confidence', 0.95)
            .having((s) => s.source, 'source', 'Barcode'),
      ],
    );

    blocTest<ScanResultBloc, ScanResultState>(
      'emits [ScanResultProcessing, ScanResultFailure] when recognition fails',
      build: () {
        when(() => mockRecognition.recognizeAlbum(any()))
            .thenAnswer((_) async => RecognitionPipelineResult(
                  bestResult: RecognitionResult(
                    confidence: 0.0,
                    source: 'none',
                    errorMessage: 'No match found',
                  ),
                  pipelineSummary: 'Barcode -> OCR -> Discogs -> Fail',
                  stepsAttempted: 5,
                  stepsSucceeded: 0,
                ));
        return createBloc();
      },
      act: (bloc) => bloc.add(const StartRecognition('/tmp/photo.jpg')),
      expect: () => [
        isA<ScanResultProcessing>(),
        isA<ScanResultFailure>()
            .having((s) => s.message, 'message', 'No match found')
            .having((s) => s.imagePath, 'imagePath', '/tmp/photo.jpg'),
      ],
    );

    blocTest<ScanResultBloc, ScanResultState>(
      'emits [ScanResultProcessing, ScanResultFailure] on exception',
      build: () {
        when(() => mockRecognition.recognizeAlbum(any()))
            .thenThrow(Exception('Network error'));
        return createBloc();
      },
      act: (bloc) => bloc.add(const StartRecognition('/tmp/photo.jpg')),
      expect: () => [
        isA<ScanResultProcessing>(),
        isA<ScanResultFailure>(),
      ],
    );

    blocTest<ScanResultBloc, ScanResultState>(
      'uses rawApiData for album construction when available',
      build: () {
        when(() => mockRecognition.recognizeAlbum(any()))
            .thenAnswer((_) async => RecognitionPipelineResult(
                  bestResult: RecognitionResult(
                    albumTitle: 'Raw Title',
                    artist: 'Raw Artist',
                    confidence: 0.85,
                    source: 'online',
                    rawApiData: {
                      'title': 'API Title',
                      'artist': 'API Artist',
                      'releaseYear': 2020,
                      'label': 'API Label',
                      'tracklist': ['Track 1', 'Track 2'],
                      'musicBrainzId': 'mb-123',
                    },
                  ),
                  pipelineSummary: 'OCR -> MusicBrainz',
                  stepsAttempted: 2,
                  stepsSucceeded: 2,
                ));
        return createBloc();
      },
      act: (bloc) => bloc.add(const StartRecognition('/tmp/photo.jpg')),
      expect: () => [
        isA<ScanResultProcessing>(),
        isA<ScanResultSuccess>()
            .having((s) => s.album.title, 'title', 'API Title')
            .having((s) => s.album.artist, 'artist', 'API Artist')
            .having((s) => s.album.releaseYear, 'releaseYear', 2020)
            .having((s) => s.album.label, 'label', 'API Label')
            .having((s) => s.album.tracklist, 'tracklist', ['Track 1', 'Track 2'])
            .having((s) => s.album.musicBrainzId, 'musicBrainzId', 'mb-123'),
      ],
    );

    blocTest<ScanResultBloc, ScanResultState>(
      'falls back to result fields when rawApiData is null',
      build: () {
        when(() => mockRecognition.recognizeAlbum(any()))
            .thenAnswer((_) async => RecognitionPipelineResult(
                  bestResult: RecognitionResult(
                    albumTitle: 'Fallback Title',
                    artist: 'Fallback Artist',
                    confidence: 0.7,
                    source: 'ocr',
                  ),
                  pipelineSummary: 'OCR -> Discogs',
                  stepsAttempted: 3,
                  stepsSucceeded: 1,
                ));
        return createBloc();
      },
      act: (bloc) => bloc.add(const StartRecognition('/tmp/photo.jpg')),
      expect: () => [
        isA<ScanResultProcessing>(),
        isA<ScanResultSuccess>()
            .having((s) => s.album.title, 'title', 'Fallback Title')
            .having((s) => s.album.artist, 'artist', 'Fallback Artist'),
      ],
    );
  });

  // ---------------------------------------------------------------
  // ManualSearch
  // ---------------------------------------------------------------
  group('ManualSearch', () {
    blocTest<ScanResultBloc, ScanResultState>(
      'emits [ScanResultProcessing, ScanResultSuccess] on successful search',
      build: () {
        when(() => mockRecognition.searchByQuery(any(), any()))
            .thenAnswer((_) async => RecognitionResultFactory.create(
                  albumTitle: 'A Love Supreme',
                  artist: 'John Coltrane',
                  confidence: 0.9,
                  source: 'online',
                  rawApiData: {
                    'title': 'A Love Supreme',
                    'artist': 'John Coltrane',
                    'releaseYear': 1965,
                  },
                ));
        return createBloc();
      },
      act: (bloc) => bloc.add(
        const ManualSearch(artist: 'John Coltrane', album: 'A Love Supreme'),
      ),
      expect: () => [
        isA<ScanResultProcessing>().having(
          (s) => s.currentStep,
          'currentStep',
          'Searching...',
        ),
        isA<ScanResultSuccess>()
            .having((s) => s.album.title, 'title', 'A Love Supreme')
            .having((s) => s.confidence, 'confidence', 0.9),
      ],
    );

    blocTest<ScanResultBloc, ScanResultState>(
      'emits [ScanResultProcessing, ScanResultFailure] when no results found',
      build: () {
        when(() => mockRecognition.searchByQuery(any(), any()))
            .thenAnswer((_) async => RecognitionResultFactory.noMatch());
        return createBloc();
      },
      act: (bloc) => bloc.add(
        const ManualSearch(artist: 'Unknown', album: 'Nonexistent'),
      ),
      expect: () => [
        isA<ScanResultProcessing>(),
        isA<ScanResultFailure>(),
      ],
    );

    blocTest<ScanResultBloc, ScanResultState>(
      'emits [ScanResultProcessing, ScanResultFailure] on search error',
      build: () {
        when(() => mockRecognition.searchByQuery(any(), any()))
            .thenThrow(Exception('Network error'));
        return createBloc();
      },
      act: (bloc) => bloc.add(
        const ManualSearch(artist: 'Test', album: 'Test'),
      ),
      expect: () => [
        isA<ScanResultProcessing>(),
        isA<ScanResultFailure>(),
      ],
    );
  });

  // ---------------------------------------------------------------
  // ConfirmAndSave
  // ---------------------------------------------------------------
  group('ConfirmAndSave', () {
    blocTest<ScanResultBloc, ScanResultState>(
      'saves album and emits ScanResultSaved',
      build: () {
        final album = AlbumFactory.create();
        when(() => mockRepository.addAlbum(album)).thenAnswer((_) async => album);
        return createBloc();
      },
      act: (bloc) => bloc.add(ConfirmAndSave(AlbumFactory.create())),
      expect: () => [
        isA<ScanResultSaved>(),
      ],
      verify: (bloc) {
        verify(() => mockRepository.addAlbum(any())).called(1);
      },
    );

    blocTest<ScanResultBloc, ScanResultState>(
      'emits ScanResultFailure when save fails',
      build: () {
        when(() => mockRepository.addAlbum(any())).thenThrow(Exception('Save failed'));
        return createBloc();
      },
      act: (bloc) => bloc.add(ConfirmAndSave(AlbumFactory.create())),
      expect: () => [
        isA<ScanResultFailure>().having(
          (s) => s.message,
          'message',
          contains('Failed to save'),
        ),
      ],
    );
  });

  // ---------------------------------------------------------------
  // CancelRecognition
  // ---------------------------------------------------------------
  group('CancelRecognition', () {
    blocTest<ScanResultBloc, ScanResultState>(
      'emits ScanResultInitial',
      build: createBloc,
      act: (bloc) => bloc.add(CancelRecognition()),
      expect: () => [
        isA<ScanResultInitial>(),
      ],
    );
  });

  // ---------------------------------------------------------------
  // RetryRecognition
  // ---------------------------------------------------------------
  group('RetryRecognition', () {
    blocTest<ScanResultBloc, ScanResultState>(
      'retries recognition by dispatching StartRecognition',
      build: () {
        when(() => mockRecognition.recognizeAlbum(any()))
            .thenAnswer((_) async => RecognitionPipelineResult(
                  bestResult: RecognitionResultFactory.create(
                    albumTitle: 'Retry Success',
                    confidence: 0.88,
                    source: 'online',
                  ),
                  pipelineSummary: 'Retry -> Success',
                  stepsAttempted: 1,
                  stepsSucceeded: 1,
                ));
        return createBloc();
      },
      act: (bloc) => bloc.add(const RetryRecognition('/tmp/photo.jpg')),
      expect: () => [
        isA<ScanResultProcessing>(),
        isA<ScanResultSuccess>(),
      ],
    );
  });
}
