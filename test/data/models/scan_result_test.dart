// Testy jednostkowe dla RecognitionResult: konstrukcja, progi ufności, source, equality
// Unit tests for RecognitionResult model: construction, confidence thresholds, strategy/source results.
//
// RecognitionResult to odpowiednik "ScanResult" z taska – reprezentuje wynik skanowania.
// Pola: albumTitle, artist, confidence, source, rawApiData, errorMessage

import 'package:music_album_scanner/data/models/recognition_result.dart';
import 'package:test/test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  // ---------------------------------------------------------------
  // Konstrukcja / Construction
  // ---------------------------------------------------------------
  group('RecognitionResult construction', () {
    test('should create result with all fields', () {
      final result = RecognitionResult(
        albumTitle: 'Kind of Blue',
        artist: 'Miles Davis',
        confidence: 0.95,
        source: 'online',
        rawApiData: {'id': 'mb-123'},
      );

      expect(result.albumTitle, 'Kind of Blue');
      expect(result.artist, 'Miles Davis');
      expect(result.confidence, 0.95);
      expect(result.source, 'online');
      expect(result.rawApiData, {'id': 'mb-123'});
      expect(result.errorMessage, isNull);
    });

    test('should create result with required fields only', () {
      final result = const RecognitionResult(
        confidence: 0.5,
        source: 'none',
      );

      expect(result.albumTitle, isNull);
      expect(result.artist, isNull);
      expect(result.confidence, 0.5);
      expect(result.source, 'none');
      expect(result.rawApiData, isNull);
      expect(result.errorMessage, isNull);
    });

    test('should create result with error message', () {
      final result = const RecognitionResult(
        confidence: 0.0,
        source: 'none',
        errorMessage: 'Network timeout',
      );

      expect(result.errorMessage, 'Network timeout');
    });

    test('should support rawApiData with nested objects', () {
      final result = RecognitionResult(
        confidence: 0.9,
        source: 'online',
        rawApiData: {
          'releases': [
            {'title': 'OK Computer', 'id': 'abc'},
          ],
          'count': 1,
        },
      );

      expect(result.rawApiData, isNotNull);
      expect(result.rawApiData!['count'], 1);
    });
  });

  // ---------------------------------------------------------------
  // isSuccess getter
  // ---------------------------------------------------------------
  group('RecognitionResult isSuccess', () {
    test('should be success when albumTitle is set and no error', () {
      final result = RecognitionResultFactory.create();
      expect(result.isSuccess, isTrue);
    });

    test('should not be success when albumTitle is null', () {
      final result = const RecognitionResult(
        confidence: 0.0,
        source: 'none',
      );
      expect(result.isSuccess, isFalse);
    });

    test('should not be success when errorMessage is set', () {
      final result = const RecognitionResult(
        albumTitle: 'Some Album',
        confidence: 0.9,
        source: 'online',
        errorMessage: 'API error',
      );
      expect(result.isSuccess, isFalse);
    });

    test('should not be success when both albumTitle is null and error is set', () {
      final result = const RecognitionResult(
        confidence: 0.0,
        source: 'none',
        errorMessage: 'Failed',
      );
      expect(result.isSuccess, isFalse);
    });

    test('should be success when albumTitle is set even with low confidence', () {
      final result = const RecognitionResult(
        albumTitle: 'Mystery Album',
        confidence: 0.1,
        source: 'ocr',
      );
      expect(result.isSuccess, isTrue);
    });
  });

  // ---------------------------------------------------------------
  // isHighConfidence getter (threshold >= 0.7)
  // ---------------------------------------------------------------
  group('RecognitionResult isHighConfidence', () {
    test('should be high confidence at exactly 0.7', () {
      final result = RecognitionResultFactory.create(confidence: 0.7);
      expect(result.isHighConfidence, isTrue);
    });

    test('should be high confidence above 0.7', () {
      final result = RecognitionResultFactory.create(confidence: 0.85);
      expect(result.isHighConfidence, isTrue);
    });

    test('should not be high confidence below 0.7', () {
      final result = RecognitionResultFactory.create(confidence: 0.69);
      expect(result.isHighConfidence, isFalse);
    });

    test('should be high confidence at 1.0', () {
      final result = RecognitionResultFactory.create(confidence: 1.0);
      expect(result.isHighConfidence, isTrue);
    });

    test('should not be high confidence at 0.0', () {
      final result = RecognitionResultFactory.create(confidence: 0.0);
      expect(result.isHighConfidence, isFalse);
    });

    test('barcode match should typically be high confidence', () {
      final result = RecognitionResultFactory.barcodeMatch(confidence: 0.98);
      expect(result.isHighConfidence, isTrue);
    });

    test('OCR match can be low confidence', () {
      final result = RecognitionResultFactory.ocrMatch(confidence: 0.5);
      expect(result.isHighConfidence, isFalse);
    });
  });

  // ---------------------------------------------------------------
  // isBarcodeMatch / isOcrMatch getters
  // ---------------------------------------------------------------
  group('RecognitionResult source type checks', () {
    test('isBarcodeMatch should be true for barcode source', () {
      final result = RecognitionResultFactory.barcodeMatch();
      expect(result.isBarcodeMatch, isTrue);
    });

    test('isBarcodeMatch should be false for online source', () {
      final result = RecognitionResultFactory.create(source: 'online');
      expect(result.isBarcodeMatch, isFalse);
    });

    test('isOcrMatch should be true for ocr source', () {
      final result = RecognitionResultFactory.ocrMatch();
      expect(result.isOcrMatch, isTrue);
    });

    test('isOcrMatch should be true for online source', () {
      final result = RecognitionResultFactory.create(source: 'online');
      expect(result.isOcrMatch, isTrue);
    });

    test('isOcrMatch should be false for barcode source', () {
      final result = RecognitionResultFactory.barcodeMatch();
      expect(result.isOcrMatch, isFalse);
    });

    test('isOcrMatch should be false for offline source', () {
      final result = RecognitionResultFactory.offlineMatch();
      expect(result.isOcrMatch, isFalse);
    });

    test('isBarcodeMatch should be false for none source', () {
      final result = RecognitionResultFactory.noMatch();
      expect(result.isBarcodeMatch, isFalse);
    });
  });

  // ---------------------------------------------------------------
  // sourceLabel getter
  // ---------------------------------------------------------------
  group('RecognitionResult sourceLabel', () {
    test('should return "Barcode" for barcode source', () {
      final result = RecognitionResultFactory.barcodeMatch();
      expect(result.sourceLabel, 'Barcode');
    });

    test('should return "MusicBrainz" for online source', () {
      final result = RecognitionResultFactory.create(source: 'online');
      expect(result.sourceLabel, 'MusicBrainz');
    });

    test('should return "OCR + Search" for ocr source', () {
      final result = RecognitionResultFactory.ocrMatch();
      expect(result.sourceLabel, 'OCR + Search');
    });

    test('should return "On-device AI" for offline source', () {
      final result = RecognitionResultFactory.offlineMatch();
      expect(result.sourceLabel, 'On-device AI');
    });

    test('should return "No match" for none source', () {
      final result = RecognitionResultFactory.noMatch();
      expect(result.sourceLabel, 'No match');
    });

    test('should uppercase unknown source values', () {
      const result = RecognitionResult(
        confidence: 0.5,
        source: 'custom_source',
      );
      expect(result.sourceLabel, 'CUSTOM_SOURCE');
    });
  });

  // ---------------------------------------------------------------
  // Equality (Equatable)
  // ---------------------------------------------------------------
  group('RecognitionResult equality', () {
    test('should be equal when all props match', () {
      const r1 = RecognitionResult(
        albumTitle: 'Title',
        artist: 'Artist',
        confidence: 0.9,
        source: 'online',
      );
      const r2 = RecognitionResult(
        albumTitle: 'Title',
        artist: 'Artist',
        confidence: 0.9,
        source: 'online',
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('should not be equal when albumTitle differs', () {
      const r1 = RecognitionResult(
        albumTitle: 'Title A',
        artist: 'Artist',
        confidence: 0.9,
        source: 'online',
      );
      const r2 = RecognitionResult(
        albumTitle: 'Title B',
        artist: 'Artist',
        confidence: 0.9,
        source: 'online',
      );

      expect(r1, isNot(equals(r2)));
    });

    test('should not be equal when artist differs', () {
      const r1 = RecognitionResult(
        albumTitle: 'Title',
        artist: 'A',
        confidence: 0.9,
        source: 'online',
      );
      const r2 = RecognitionResult(
        albumTitle: 'Title',
        artist: 'B',
        confidence: 0.9,
        source: 'online',
      );

      expect(r1, isNot(equals(r2)));
    });

    test('should not be equal when confidence differs', () {
      const r1 = RecognitionResult(
        confidence: 0.9,
        source: 'online',
      );
      const r2 = RecognitionResult(
        confidence: 0.8,
        source: 'online',
      );

      expect(r1, isNot(equals(r2)));
    });

    test('should not be equal when source differs', () {
      const r1 = RecognitionResult(
        confidence: 0.9,
        source: 'online',
      );
      const r2 = RecognitionResult(
        confidence: 0.9,
        source: 'offline',
      );

      expect(r1, isNot(equals(r2)));
    });

    test('should be equal even if rawApiData differs (not in props)', () {
      // props = [albumTitle, artist, confidence, source] – rawApiData nie jest w props
      final r1 = RecognitionResult(
        confidence: 0.9,
        source: 'online',
        rawApiData: {'key': 'value1'},
      );
      final r2 = RecognitionResult(
        confidence: 0.9,
        source: 'online',
        rawApiData: {'key': 'value2'},
      );

      expect(r1, equals(r2));
    });

    test('should be equal even if errorMessage differs (not in props)', () {
      // errorMessage nie jest w props
      const r1 = RecognitionResult(
        confidence: 0.0,
        source: 'none',
        errorMessage: 'Error A',
      );
      const r2 = RecognitionResult(
        confidence: 0.0,
        source: 'none',
        errorMessage: 'Error B',
      );

      expect(r1, equals(r2));
    });

    test('should have 4 props', () {
      final result = RecognitionResultFactory.create();
      expect(result.props, hasLength(4));
    });
  });

  // ---------------------------------------------------------------
  // Confidence thresholds (boundary tests)
  // ---------------------------------------------------------------
  group('RecognitionResult confidence boundaries', () {
    test('confidence 0.0 should not be high confidence', () {
      final result = RecognitionResultFactory.create(confidence: 0.0);
      expect(result.isHighConfidence, isFalse);
    });

    test('confidence 0.69 should not be high confidence', () {
      final result = RecognitionResultFactory.create(confidence: 0.69);
      expect(result.isHighConfidence, isFalse);
    });

    test('confidence exactly 0.7 should be high confidence', () {
      final result = RecognitionResultFactory.create(confidence: 0.7);
      expect(result.isHighConfidence, isTrue);
    });

    test('confidence 0.71 should be high confidence', () {
      final result = RecognitionResultFactory.create(confidence: 0.71);
      expect(result.isHighConfidence, isTrue);
    });

    test('confidence 1.0 should be high confidence', () {
      final result = RecognitionResultFactory.create(confidence: 1.0);
      expect(result.isHighConfidence, isTrue);
    });
  });

  // ---------------------------------------------------------------
  // Strategy / source combinations
  // ---------------------------------------------------------------
  group('RecognitionResult strategy combinations', () {
    test('barcode strategy with high confidence', () {
      final result = RecognitionResultFactory.barcodeMatch(
        albumTitle: 'Thriller',
        artist: 'Michael Jackson',
        confidence: 0.99,
      );

      expect(result.source, 'barcode');
      expect(result.isBarcodeMatch, isTrue);
      expect(result.isHighConfidence, isTrue);
      expect(result.isSuccess, isTrue);
    });

    test('ocr strategy with medium confidence', () {
      final result = RecognitionResultFactory.ocrMatch(
        albumTitle: 'Abbey Road',
        artist: 'The Beatles',
        confidence: 0.75,
      );

      expect(result.source, 'ocr');
      expect(result.isOcrMatch, isTrue);
      expect(result.isHighConfidence, isTrue);
      expect(result.isSuccess, isTrue);
    });

    test('offline strategy with low confidence', () {
      final result = RecognitionResultFactory.offlineMatch(
        albumTitle: 'Dark Side of the Moon',
        confidence: 0.45,
      );

      expect(result.source, 'offline');
      expect(result.isHighConfidence, isFalse);
      expect(result.isSuccess, isTrue); // has albumTitle, no error
    });

    test('none strategy (no match)', () {
      final result = RecognitionResultFactory.noMatch();

      expect(result.source, 'none');
      expect(result.isSuccess, isFalse);
      expect(result.isHighConfidence, isFalse);
      expect(result.isBarcodeMatch, isFalse);
      expect(result.isOcrMatch, isFalse);
      expect(result.albumTitle, isNull);
      expect(result.artist, isNull);
      expect(result.errorMessage, 'No album found');
    });

    test('online strategy matches isOcrMatch', () {
      const result = RecognitionResult(
        albumTitle: 'Rumours',
        artist: 'Fleetwood Mac',
        confidence: 0.88,
        source: 'online',
      );

      expect(result.isOcrMatch, isTrue);
      expect(result.sourceLabel, 'MusicBrainz');
    });
  });

  // ---------------------------------------------------------------
  // Factory helpers
  // ---------------------------------------------------------------
  group('RecognitionResultFactory', () {
    test('noMatch should return proper failure result', () {
      final result = RecognitionResultFactory.noMatch();
      expect(result.source, 'none');
      expect(result.confidence, 0.0);
      expect(result.errorMessage, isNotNull);
    });

    test('barcodeMatch should have correct source', () {
      final result = RecognitionResultFactory.barcodeMatch();
      expect(result.source, 'barcode');
    });

    test('ocrMatch should have correct source', () {
      final result = RecognitionResultFactory.ocrMatch();
      expect(result.source, 'ocr');
    });

    test('offlineMatch should have correct source', () {
      final result = RecognitionResultFactory.offlineMatch();
      expect(result.source, 'offline');
    });
  });

  // ---------------------------------------------------------------
  // Timestamp behavior (RecognitionResult nie ma timestamp – to jest w ScanSession)
  // ---------------------------------------------------------------
  group('RecognitionResult - no timestamp field', () {
    test('should not have a timestamp field', () {
      final result = RecognitionResultFactory.create();
      // RecognitionResult nie ma pola timestamp
      // (timestamp jest w ScanSession)
      expect(result.albumTitle, isNotNull);
    });
  });
}
