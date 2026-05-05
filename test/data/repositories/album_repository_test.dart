import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_album_scanner/data/models/album_model.dart';
import 'package:music_album_scanner/data/repositories/album_repository.dart';
import 'package:music_album_scanner/data/services/storage/local_storage_service.dart';

import '../../helpers/test_helpers.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late AlbumRepository repository;
  late MockLocalStorageService mockStorage;

  setUp(() {
    mockStorage = MockLocalStorageService();
    repository = AlbumRepository(mockStorage);
  });

  // ---------------------------------------------------------------
  // addAlbum
  // ---------------------------------------------------------------
  group('addAlbum', () {
    test('delegates to storage and returns the album', () async {
      final album = AlbumFactory.create();

      when(() => mockStorage.addAlbum(album)).thenAnswer((_) async => album);

      final result = await repository.addAlbum(album);

      expect(result, album);
      verify(() => mockStorage.addAlbum(album)).called(1);
    });

    test('propagates storage error', () async {
      final album = AlbumFactory.create();

      when(() => mockStorage.addAlbum(album)).thenThrow(Exception('Storage error'));

      expect(
        () => repository.addAlbum(album),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ---------------------------------------------------------------
  // createAlbum
  // ---------------------------------------------------------------
  group('createAlbum', () {
    test('delegates to storage with all parameters', () async {
      final album = AlbumFactory.create();

      when(() => mockStorage.createAlbumFromRecognition(
            title: any(named: 'title'),
            artist: any(named: 'artist'),
            releaseYear: any(named: 'releaseYear'),
            label: any(named: 'label'),
            genre: any(named: 'genre'),
            tracklist: any(named: 'tracklist'),
            coverArtUrl: any(named: 'coverArtUrl'),
            userPhotoPath: any(named: 'userPhotoPath'),
            musicBrainzId: any(named: 'musicBrainzId'),
            discogsId: any(named: 'discogsId'),
            confidence: any(named: 'confidence'),
          )).thenAnswer((_) async => album);

      final result = await repository.createAlbum(
        title: 'Kind of Blue',
        artist: 'Miles Davis',
        releaseYear: 1959,
        label: 'Columbia Records',
        genre: 'Jazz',
        tracklist: ['So What', 'Freddie Freeloader'],
        coverArtUrl: 'https://example.com/cover.jpg',
        userPhotoPath: '/tmp/photo.jpg',
        musicBrainzId: 'mb-001',
        discogsId: 'dg-001',
        confidence: 0.95,
      );

      expect(result, album);
      verify(() => mockStorage.createAlbumFromRecognition(
            title: 'Kind of Blue',
            artist: 'Miles Davis',
            releaseYear: 1959,
            label: 'Columbia Records',
            genre: 'Jazz',
            tracklist: ['So What', 'Freddie Freeloader'],
            coverArtUrl: 'https://example.com/cover.jpg',
            userPhotoPath: '/tmp/photo.jpg',
            musicBrainzId: 'mb-001',
            discogsId: 'dg-001',
            confidence: 0.95,
          )).called(1);
    });

    test('works with only required parameters', () async {
      final album = AlbumFactory.createMinimal();

      when(() => mockStorage.createAlbumFromRecognition(
            title: any(named: 'title'),
            artist: any(named: 'artist'),
            releaseYear: any(named: 'releaseYear'),
            label: any(named: 'label'),
            genre: any(named: 'genre'),
            tracklist: any(named: 'tracklist'),
            coverArtUrl: any(named: 'coverArtUrl'),
            userPhotoPath: any(named: 'userPhotoPath'),
            musicBrainzId: any(named: 'musicBrainzId'),
            discogsId: any(named: 'discogsId'),
            confidence: any(named: 'confidence'),
          )).thenAnswer((_) async => album);

      final result = await repository.createAlbum(
        title: 'Unknown Album',
        artist: 'Unknown Artist',
      );

      expect(result, album);
    });
  });

  // ---------------------------------------------------------------
  // getAllAlbums
  // ---------------------------------------------------------------
  group('getAllAlbums', () {
    test('returns all albums from storage', () {
      final albums = AlbumFactory.createList(3);

      when(() => mockStorage.getAllAlbums()).thenReturn(albums);

      final result = repository.getAllAlbums();

      expect(result.length, 3);
      verify(() => mockStorage.getAllAlbums()).called(1);
    });

    test('returns empty list when no albums exist', () {
      when(() => mockStorage.getAllAlbums()).thenReturn([]);

      final result = repository.getAllAlbums();

      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------
  // getAlbum (getById)
  // ---------------------------------------------------------------
  group('getAlbum', () {
    test('returns album when found', () {
      final album = AlbumFactory.create(id: 'test-id-001');

      when(() => mockStorage.getAlbum('test-id-001')).thenReturn(album);

      final result = repository.getAlbum('test-id-001');

      expect(result, isNotNull);
      expect(result!.id, 'test-id-001');
    });

    test('returns null when album not found', () {
      when(() => mockStorage.getAlbum('nonexistent')).thenReturn(null);

      final result = repository.getAlbum('nonexistent');

      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------
  // updateAlbum
  // ---------------------------------------------------------------
  group('updateAlbum', () {
    test('delegates update to storage', () async {
      final album = AlbumFactory.create(title: 'Updated Title');

      when(() => mockStorage.updateAlbum(album)).thenAnswer((_) async {});

      await repository.updateAlbum(album);

      verify(() => mockStorage.updateAlbum(album)).called(1);
    });

    test('propagates storage error on update', () async {
      final album = AlbumFactory.create();

      when(() => mockStorage.updateAlbum(album)).thenThrow(Exception('Update failed'));

      expect(
        () => repository.updateAlbum(album),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ---------------------------------------------------------------
  // deleteAlbum
  // ---------------------------------------------------------------
  group('deleteAlbum', () {
    test('delegates delete to storage', () async {
      when(() => mockStorage.deleteAlbum('album-001')).thenAnswer((_) async {});

      await repository.deleteAlbum('album-001');

      verify(() => mockStorage.deleteAlbum('album-001')).called(1);
    });

    test('propagates storage error on delete', () async {
      when(() => mockStorage.deleteAlbum('album-001')).thenThrow(Exception('Delete failed'));

      expect(
        () => repository.deleteAlbum('album-001'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ---------------------------------------------------------------
  // search
  // ---------------------------------------------------------------
  group('search', () {
    test('delegates search to storage', () {
      final albums = AlbumFactory.createList(2);

      when(() => mockStorage.searchCollection('Miles')).thenReturn(albums);

      final result = repository.search('Miles');

      expect(result.length, 2);
      verify(() => mockStorage.searchCollection('Miles')).called(1);
    });

    test('returns empty list when no matches', () {
      when(() => mockStorage.searchCollection('nonexistent')).thenReturn([]);

      final result = repository.search('nonexistent');

      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------
  // count
  // ---------------------------------------------------------------
  group('count', () {
    test('returns album count from storage', () {
      when(() => mockStorage.albumCount).thenReturn(42);

      expect(repository.count, 42);
      verify(() => mockStorage.albumCount).called(1);
    });

    test('returns zero when no albums', () {
      when(() => mockStorage.albumCount).thenReturn(0);

      expect(repository.count, 0);
    });
  });

  // ---------------------------------------------------------------
  // exportCollection
  // ---------------------------------------------------------------
  group('exportCollection', () {
    test('delegates export to storage', () {
      final exportData = [
        {'id': 'album-001', 'title': 'Test Album'},
      ];

      when(() => mockStorage.exportToJson()).thenReturn(exportData);

      final result = repository.exportCollection();

      expect(result.length, 1);
      expect(result[0]['title'], 'Test Album');
      verify(() => mockStorage.exportToJson()).called(1);
    });

    test('returns empty list when no albums', () {
      when(() => mockStorage.exportToJson()).thenReturn([]);

      final result = repository.exportCollection();

      expect(result, isEmpty);
    });
  });
}
