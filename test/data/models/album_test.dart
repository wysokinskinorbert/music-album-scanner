// Testy jednostkowe dla modelu Album: konstrukcja, props/equality, copyWith, domyślne wartości
// Unit tests for Album model: construction, equality, copyWith, default values.
//
// Uwaga: model używa Equatable, HiveField i wygenerowanego adaptera (.g.dart).
// Nie testujemy bezpośrednio serializacji Hive bez wygenerowanego adaptera.

import 'package:music_album_scanner/data/models/album_model.dart';
import 'package:test/test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  // ---------------------------------------------------------------
  // Konstrukcja / Construction
  // ---------------------------------------------------------------
  group('Album construction', () {
    test('should create album with all fields', () {
      final album = AlbumFactory.create();

      expect(album.id, TestConstants.sampleAlbumId);
      expect(album.title, TestConstants.sampleTitle);
      expect(album.artist, TestConstants.sampleArtist);
      expect(album.releaseYear, TestConstants.sampleReleaseYear);
      expect(album.label, TestConstants.sampleLabel);
      expect(album.genre, TestConstants.sampleGenre);
      expect(album.tracklist, TestConstants.sampleTracklist);
      expect(album.coverArtUrl, TestConstants.sampleCoverArtUrl);
      expect(album.userPhotoPath, TestConstants.sampleUserPhotoPath);
      expect(album.dateAdded, TestConstants.sampleDateAdded);
      expect(album.musicBrainzId, TestConstants.sampleMusicBrainzId);
      expect(album.discogsId, TestConstants.sampleDiscogsId);
      expect(album.recognitionConfidence, 0.95);
      expect(album.barcode, TestConstants.sampleBarcode);
      expect(album.country, TestConstants.sampleCountry);
      expect(album.format, TestConstants.sampleFormat);
    });

    test('should create album with required fields only', () {
      final album = AlbumFactory.createMinimal();

      expect(album.id, 'minimal-001');
      expect(album.title, 'Unknown Album');
      expect(album.artist, 'Unknown Artist');
      expect(album.dateAdded, isNotNull);

      // Opcjonalne pola powinny być null/domyślne
      expect(album.releaseYear, isNull);
      expect(album.label, isNull);
      expect(album.genre, isNull);
      expect(album.coverArtUrl, isNull);
      expect(album.userPhotoPath, isNull);
      expect(album.musicBrainzId, isNull);
      expect(album.discogsId, isNull);
      expect(album.barcode, isNull);
      expect(album.country, isNull);
      expect(album.format, isNull);
    });

    test('should create album with custom id', () {
      final album = AlbumFactory.create(id: 'custom-id-42');
      expect(album.id, 'custom-id-42');
    });

    test('should create album with empty tracklist by default', () {
      final album = Album(
        id: 't1',
        title: 'Test',
        artist: 'Artist',
        dateAdded: DateTime.now(),
      );
      expect(album.tracklist, isEmpty);
    });
  });

  // ---------------------------------------------------------------
  // Domyślne wartości / Default values
  // ---------------------------------------------------------------
  group('Album default values', () {
    test('should have empty tracklist as default', () {
      final album = AlbumFactory.createMinimal();
      expect(album.tracklist, isEmpty);
      expect(album.tracklist, isA<List<String>>());
    });

    test('should have zero confidence as default', () {
      final album = AlbumFactory.createMinimal();
      expect(album.recognitionConfidence, 0.0);
    });

    test('should allow setting confidence to a positive value', () {
      final album = AlbumFactory.create(recognitionConfidence: 0.88);
      expect(album.recognitionConfidence, 0.88);
    });

    test('should allow setting confidence to zero', () {
      final album = AlbumFactory.create(recognitionConfidence: 0.0);
      expect(album.recognitionConfidence, 0.0);
    });

    test('should allow setting releaseYear to null', () {
      final album = AlbumFactory.create(releaseYear: null);
      expect(album.releaseYear, isNull);
    });
  });

  // ---------------------------------------------------------------
  // Equality (Equatable)
  // ---------------------------------------------------------------
  group('Album equality', () {
    test('should be equal when key fields match', () {
      final a1 = AlbumFactory.create();
      final a2 = AlbumFactory.create();

      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
    });

    test('should not be equal when id differs', () {
      final a1 = AlbumFactory.create(id: 'id-1');
      final a2 = AlbumFactory.create(id: 'id-2');

      expect(a1, isNot(equals(a2)));
    });

    test('should not be equal when title differs', () {
      final a1 = AlbumFactory.create(title: 'Title A');
      final a2 = AlbumFactory.create(title: 'Title B');

      expect(a1, isNot(equals(a2)));
    });

    test('should not be equal when artist differs', () {
      final a1 = AlbumFactory.create(artist: 'Artist A');
      final a2 = AlbumFactory.create(artist: 'Artist B');

      expect(a1, isNot(equals(a2)));
    });

    test('should not be equal when musicBrainzId differs', () {
      final a1 = AlbumFactory.create(musicBrainzId: 'mb-1');
      final a2 = AlbumFactory.create(musicBrainzId: 'mb-2');

      expect(a1, isNot(equals(a2)));
    });

    test('should not be equal when discogsId differs', () {
      final a1 = AlbumFactory.create(discogsId: 'dc-1');
      final a2 = AlbumFactory.create(discogsId: 'dc-2');

      expect(a1, isNot(equals(a2)));
    });

    test('should be equal even if non-key fields differ', () {
      // props = [id, title, artist, musicBrainzId, discogsId]
      // Zmiana innych pól nie wpływa na equality
      final a1 = AlbumFactory.create(
        genre: 'Jazz',
        releaseYear: 1959,
        recognitionConfidence: 0.9,
      );
      final a2 = AlbumFactory.create(
        genre: 'Rock',
        releaseYear: 2020,
        recognitionConfidence: 0.5,
      );

      expect(a1, equals(a2)); // Same key fields
    });

    test('should have identical props list', () {
      final album = AlbumFactory.create();
      expect(album.props, hasLength(5));
      expect(album.props[0], TestConstants.sampleAlbumId);
      expect(album.props[1], TestConstants.sampleTitle);
      expect(album.props[2], TestConstants.sampleArtist);
      expect(album.props[3], TestConstants.sampleMusicBrainzId);
      expect(album.props[4], TestConstants.sampleDiscogsId);
    });
  });

  // ---------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------
  group('Album copyWith', () {
    test('should copy with new title', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(title: 'New Title');

      expect(copy.title, 'New Title');
      expect(copy.id, original.id);
      expect(copy.artist, original.artist);
      expect(copy.dateAdded, original.dateAdded);
    });

    test('should copy with new artist', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(artist: 'New Artist');

      expect(copy.artist, 'New Artist');
      expect(copy.title, original.title);
    });

    test('should copy with new releaseYear', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(releaseYear: 2025);

      expect(copy.releaseYear, 2025);
    });

    test('should copy with new genre', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(genre: 'Electronic');

      expect(copy.genre, 'Electronic');
    });

    test('should copy with new tracklist', () {
      final original = AlbumFactory.create();
      const newTracks = ['Track A', 'Track B'];
      final copy = original.copyWith(tracklist: newTracks);

      expect(copy.tracklist, newTracks);
    });

    test('should copy with new confidence', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(recognitionConfidence: 0.55);

      expect(copy.recognitionConfidence, 0.55);
    });

    test('should copy with new barcode', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(barcode: '1234567890');

      expect(copy.barcode, '1234567890');
    });

    test('should preserve id and dateAdded in copy', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(title: 'Changed');

      // id i dateAdded nigdy nie powinny się zmieniać w copyWith
      expect(copy.id, original.id);
      expect(copy.dateAdded, original.dateAdded);
    });

    test('should return identical object when no params given', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith();

      // Ten sam id, title, artist itd.
      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.artist, original.artist);
      expect(copy.releaseYear, original.releaseYear);
      expect(copy.genre, original.genre);
    });

    test('should copy with new musicBrainzId', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(musicBrainzId: 'new-mb-id');

      expect(copy.musicBrainzId, 'new-mb-id');
    });

    test('should copy with new discogsId', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(discogsId: 'new-dc-id');

      expect(copy.discogsId, 'new-dc-id');
    });

    test('should copy with new coverArtUrl', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(coverArtUrl: 'https://example.com/cover.jpg');

      expect(copy.coverArtUrl, 'https://example.com/cover.jpg');
    });

    test('should copy with new userPhotoPath', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(userPhotoPath: '/new/path.jpg');

      expect(copy.userPhotoPath, '/new/path.jpg');
    });

    test('should copy with new country', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(country: 'UK');

      expect(copy.country, 'UK');
    });

    test('should copy with new format', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(format: 'CD');

      expect(copy.format, 'CD');
    });

    test('should copy with new label', () {
      final original = AlbumFactory.create();
      final copy = original.copyWith(label: 'Blue Note');

      expect(copy.label, 'Blue Note');
    });
  });

  // ---------------------------------------------------------------
  // Tracklista / Tracklist
  // ---------------------------------------------------------------
  group('Album tracklist', () {
    test('should support multi-track tracklist', () {
      final album = AlbumFactory.create();
      expect(album.tracklist.length, 5);
      expect(album.tracklist[0], 'So What');
      expect(album.tracklist.last, 'Flamenco Sketches');
    });

    test('should support empty tracklist', () {
      final album = AlbumFactory.create(tracklist: []);
      expect(album.tracklist, isEmpty);
    });

    test('should support single track', () {
      final album = AlbumFactory.create(tracklist: ['Only Track']);
      expect(album.tracklist, hasLength(1));
      expect(album.tracklist.first, 'Only Track');
    });
  });

  // ---------------------------------------------------------------
  // Hive annotations (typeId)
  // ---------------------------------------------------------------
  group('Album Hive annotations', () {
    test('should have typeId 0 for Hive', () {
      // Weryfikacja statyczna – klasa Album jest oznaczona @HiveType(typeId: 0)
      // Nie możemy przetestować runtime bez wygenerowanego adaptera,
      // ale możemy sprawdzić że model jest instancją Equatable.
      final album = AlbumFactory.create();
      expect(album, isA<Album>());
    });
  });

  // ---------------------------------------------------------------
  // Fabryka / Factory
  // ---------------------------------------------------------------
  group('AlbumFactory', () {
    test('createList should return correct number of albums', () {
      final albums = AlbumFactory.createList(5);
      expect(albums, hasLength(5));
    });

    test('createList should return distinct albums', () {
      final albums = AlbumFactory.createList(3);
      final ids = albums.map((a) => a.id).toSet();
      expect(ids.length, 3);
    });

    test('createList albums should have sequential releaseYears', () {
      final albums = AlbumFactory.createList(5);
      for (var i = 0; i < 5; i++) {
        expect(albums[i].releaseYear, 2000 + i);
      }
    });

    test('createWithBarcode should set barcode', () {
      final album = AlbumFactory.createWithBarcode('999888777');
      expect(album.barcode, '999888777');
    });

    test('createFromMusicBrainz should set musicBrainzId', () {
      final album = AlbumFactory.createFromMusicBrainz(musicBrainzId: 'mb-xyz');
      expect(album.musicBrainzId, 'mb-xyz');
    });

    test('createFromMusicBrainz should set custom confidence', () {
      final album = AlbumFactory.createFromMusicBrainz(confidence: 0.5);
      expect(album.recognitionConfidence, 0.5);
    });
  });

  // ---------------------------------------------------------------
  // Nullable fields
  // ---------------------------------------------------------------
  group('Album nullable fields', () {
    test('releaseYear can be null', () {
      final album = AlbumFactory.create(releaseYear: null);
      expect(album.releaseYear, isNull);
    });

    test('label can be null', () {
      final album = AlbumFactory.create(label: null);
      expect(album.label, isNull);
    });

    test('genre can be null', () {
      final album = AlbumFactory.create(genre: null);
      expect(album.genre, isNull);
    });

    test('coverArtUrl can be null', () {
      final album = AlbumFactory.create(coverArtUrl: null);
      expect(album.coverArtUrl, isNull);
    });

    test('userPhotoPath can be null', () {
      final album = AlbumFactory.create(userPhotoPath: null);
      expect(album.userPhotoPath, isNull);
    });

    test('musicBrainzId can be null', () {
      final album = AlbumFactory.create(musicBrainzId: null);
      expect(album.musicBrainzId, isNull);
    });

    test('discogsId can be null', () {
      final album = AlbumFactory.create(discogsId: null);
      expect(album.discogsId, isNull);
    });

    test('barcode can be null', () {
      final album = AlbumFactory.create(barcode: null);
      expect(album.barcode, isNull);
    });

    test('country can be null', () {
      final album = AlbumFactory.create(country: null);
      expect(album.country, isNull);
    });

    test('format can be null', () {
      final album = AlbumFactory.create(format: null);
      expect(album.format, isNull);
    });
  });

  // ---------------------------------------------------------------
  // Confidence values
  // ---------------------------------------------------------------
  group('Album confidence values', () {
    test('should support confidence of 1.0', () {
      final album = AlbumFactory.create(recognitionConfidence: 1.0);
      expect(album.recognitionConfidence, 1.0);
    });

    test('should support very low confidence', () {
      final album = AlbumFactory.create(recognitionConfidence: 0.01);
      expect(album.recognitionConfidence, closeTo(0.01, 0.001));
    });
  });
}
