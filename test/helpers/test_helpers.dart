// Wspólne narzędzia testowe dla projektu music_album_scanner
// Common test utilities, sample data factories, and test constants.

import 'package:music_album_scanner/data/models/album_model.dart';
import 'package:music_album_scanner/data/models/recognition_result.dart';
import 'package:music_album_scanner/data/models/scan_session.dart';

/// Stałe używane w testach / Test constants
class TestConstants {
  TestConstants._();

  // Przykładowe dane albumu / Sample album data
  static const String sampleAlbumId = 'test-album-001';
  static const String sampleTitle = 'Kind of Blue';
  static const String sampleArtist = 'Miles Davis';
  static const int sampleReleaseYear = 1959;
  static const String sampleGenre = 'Jazz';
  static const String sampleLabel = 'Columbia Records';
  static const String sampleBarcode = '0074640602228';
  static const String sampleMusicBrainzId = 'b1601178-0ef3-428b-8e4c-9e4bc4d6344c';
  static const String sampleDiscogsId = '48679';
  static const String sampleCoverArtUrl =
      'https://coverartarchive.org/release/b1601178/front.jpg';
  static const String sampleUserPhotoPath = '/tmp/test_photos/kind_of_blue.jpg';
  static const String sampleCountry = 'US';
  static const String sampleFormat = 'Vinyl';

  // Referencyjna data / Reference timestamp
  static final sampleDateAdded = DateTime(2025, 1, 15, 10, 30, 0);

  // Tracklista testowa / Sample tracklist
  static const List<String> sampleTracklist = [
    'So What',
    'Freddie Freeloader',
    'Blue in Green',
    'All Blues',
    'Flamenco Sketches',
  ];

  // Progi ufności / Confidence thresholds
  static const double highConfidence = 0.95;
  static const double mediumConfidence = 0.75;
  static const double lowConfidence = 0.3;
  static const double zeroConfidence = 0.0;
  static const double confidenceThreshold = 0.7;

  // API
  static const String testMusicBrainzUrl =
      'https://musicbrainz.org/ws/2/release/?query=test';
  static const String testDiscogsUrl =
      'https://api.discogs.com/database/search?q=test';
  static const String testGenericUrl = 'https://example.com/api/test';
}

/// Fabryka obiektów Album do testów / Sample Album factory for tests.
class AlbumFactory {
  AlbumFactory._();

  /// Tworzy standardowy album testowy / Creates a default test album.
  static Album create({
    String? id,
    String? title,
    String? artist,
    int? releaseYear,
    String? label,
    String? genre,
    List<String>? tracklist,
    String? coverArtUrl,
    String? userPhotoPath,
    DateTime? dateAdded,
    String? musicBrainzId,
    String? discogsId,
    double recognitionConfidence = 0.95,
    String? barcode,
    String? country,
    String? format,
  }) {
    return Album(
      id: id ?? TestConstants.sampleAlbumId,
      title: title ?? TestConstants.sampleTitle,
      artist: artist ?? TestConstants.sampleArtist,
      releaseYear: releaseYear ?? TestConstants.sampleReleaseYear,
      label: label ?? TestConstants.sampleLabel,
      genre: genre ?? TestConstants.sampleGenre,
      tracklist: tracklist ?? TestConstants.sampleTracklist,
      coverArtUrl: coverArtUrl ?? TestConstants.sampleCoverArtUrl,
      userPhotoPath: userPhotoPath ?? TestConstants.sampleUserPhotoPath,
      dateAdded: dateAdded ?? TestConstants.sampleDateAdded,
      musicBrainzId: musicBrainzId ?? TestConstants.sampleMusicBrainzId,
      discogsId: discogsId ?? TestConstants.sampleDiscogsId,
      recognitionConfidence: recognitionConfidence,
      barcode: barcode ?? TestConstants.sampleBarcode,
      country: country ?? TestConstants.sampleCountry,
      format: format ?? TestConstants.sampleFormat,
    );
  }

  /// Minimalny album z tylko wymaganymi polami / Minimal album with required fields only.
  static Album createMinimal({
    String? id,
    String? title,
    String? artist,
    DateTime? dateAdded,
  }) {
    return Album(
      id: id ?? 'minimal-001',
      title: title ?? 'Unknown Album',
      artist: artist ?? 'Unknown Artist',
      dateAdded: dateAdded ?? DateTime(2025, 1, 1),
    );
  }

  /// Album z kodem kreskowym / Album with barcode data.
  static Album createWithBarcode(String barcode) {
    return create(barcode: barcode);
  }

  /// Album rozpoznany z MusicBrainz / Album recognized from MusicBrainz.
  static Album createFromMusicBrainz({
    String? musicBrainzId,
    double confidence = 0.85,
  }) {
    return create(
      musicBrainzId: musicBrainzId ?? 'mb-test-id-123',
      recognitionConfidence: confidence,
    );
  }

  /// Lista różnych albumów / Generates a list of distinct albums for tests.
  static List<Album> createList(int count) {
    return List.generate(count, (i) {
      return create(
        id: 'album-${i.toString().padLeft(3, '0')}',
        title: 'Test Album $i',
        artist: 'Test Artist $i',
        releaseYear: 2000 + i,
        recognitionConfidence: 0.5 + (i * 0.05),
      );
    });
  }
}

/// Fabryka obiektów RecognitionResult do testów / RecognitionResult factory.
class RecognitionResultFactory {
  RecognitionResultFactory._();

  static RecognitionResult create({
    String? albumTitle,
    String? artist,
    double confidence = 0.95,
    String source = 'online',
    Map<String, dynamic>? rawApiData,
    String? errorMessage,
  }) {
    return RecognitionResult(
      albumTitle: albumTitle ?? TestConstants.sampleTitle,
      artist: artist ?? TestConstants.sampleArtist,
      confidence: confidence,
      source: source,
      rawApiData: rawApiData,
      errorMessage: errorMessage,
    );
  }

  /// Wynik rozpoznania z kodu kreskowego / Barcode recognition result.
  static RecognitionResult barcodeMatch({
    String? albumTitle,
    String? artist,
    double confidence = 0.98,
  }) {
    return create(
      albumTitle: albumTitle,
      artist: artist,
      confidence: confidence,
      source: 'barcode',
    );
  }

  /// Wynik rozpoznania OCR / OCR recognition result.
  static RecognitionResult ocrMatch({
    String? albumTitle,
    String? artist,
    double confidence = 0.7,
  }) {
    return create(
      albumTitle: albumTitle,
      artist: artist,
      confidence: confidence,
      source: 'ocr',
    );
  }

  /// Wynik offline / Offline recognition result.
  static RecognitionResult offlineMatch({
    String? albumTitle,
    String? artist,
    double confidence = 0.6,
  }) {
    return create(
      albumTitle: albumTitle,
      artist: artist,
      confidence: confidence,
      source: 'offline',
    );
  }

  /// Brak dopasowania / No match result.
  static RecognitionResult noMatch() {
    return const RecognitionResult(
      confidence: 0.0,
      source: 'none',
      errorMessage: 'No album found',
    );
  }
}

/// Fabryka sesji skanowania / ScanSession factory.
class ScanSessionFactory {
  ScanSessionFactory._();

  static ScanSession create({
    String? id,
    String? photoPath,
    DateTime? timestamp,
    ScanStatus status = ScanStatus.initial,
  }) {
    return ScanSession(
      id: id ?? 'session-001',
      photoPath: photoPath ?? '/tmp/photo.jpg',
      timestamp: timestamp ?? DateTime(2025, 6, 1, 12, 0),
      status: status,
    );
  }
}
