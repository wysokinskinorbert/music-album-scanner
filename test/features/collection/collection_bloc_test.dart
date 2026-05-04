import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_album_scanner/data/models/album_model.dart';
import 'package:music_album_scanner/data/repositories/album_repository.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_bloc.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_event.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_state.dart';

import '../../../helpers/test_helpers.dart';

class MockAlbumRepository extends Mock implements AlbumRepository {}

void main() {
  late MockAlbumRepository mockRepository;

  setUp(() {
    mockRepository = MockAlbumRepository();
  });

  // ---------------------------------------------------------------
  // LoadCollection
  // ---------------------------------------------------------------
  group('LoadCollection', () {
    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionLoading, CollectionLoaded] when albums exist',
      build: () {
        final albums = AlbumFactory.createList(3);
        when(() => mockRepository.getAllAlbums()).thenReturn(albums);
        when(() => mockRepository.count).thenReturn(3);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(LoadCollection()),
      expect: () => [
        CollectionLoading(),
        CollectionLoaded(
          albums: AlbumFactory.createList(3),
          totalCount: 3,
        ),
      ],
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionLoading, CollectionLoaded] with empty list when no albums',
      build: () {
        when(() => mockRepository.getAllAlbums()).thenReturn([]);
        when(() => mockRepository.count).thenReturn(0);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(LoadCollection()),
      expect: () => [
        CollectionLoading(),
        const CollectionLoaded(albums: [], totalCount: 0),
      ],
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionLoading, CollectionError] on exception',
      build: () {
        when(() => mockRepository.getAllAlbums()).thenThrow(Exception('Storage error'));
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(LoadCollection()),
      expect: () => [
        CollectionLoading(),
        const CollectionError('Exception: Storage error'),
      ],
    );
  });

  // ---------------------------------------------------------------
  // SearchCollection
  // ---------------------------------------------------------------
  group('SearchCollection', () {
    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionLoaded] with search results and query',
      build: () {
        final albums = [AlbumFactory.create(title: 'Kind of Blue')];
        when(() => mockRepository.search('Blue')).thenReturn(albums);
        when(() => mockRepository.count).thenReturn(5);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(const SearchCollection('Blue')),
      expect: () => [
        CollectionLoaded(
          albums: [AlbumFactory.create(title: 'Kind of Blue')],
          searchQuery: 'Blue',
          totalCount: 5,
        ),
      ],
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionLoaded] with empty results for non-matching query',
      build: () {
        when(() => mockRepository.search('nonexistent')).thenReturn([]);
        when(() => mockRepository.count).thenReturn(3);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(const SearchCollection('nonexistent')),
      expect: () => [
        const CollectionLoaded(
          albums: [],
          searchQuery: 'nonexistent',
          totalCount: 3,
        ),
      ],
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionError] when search throws',
      build: () {
        when(() => mockRepository.search('error')).thenThrow(Exception('Search failed'));
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(const SearchCollection('error')),
      expect: () => [
        const CollectionError('Exception: Search failed'),
      ],
    );
  });

  // ---------------------------------------------------------------
  // DeleteAlbum
  // ---------------------------------------------------------------
  group('DeleteAlbum', () {
    blocTest<CollectionBloc, CollectionState>(
      'deletes album and reloads collection',
      build: () {
        when(() => mockRepository.deleteAlbum('album-001')).thenAnswer((_) async {});
        when(() => mockRepository.getAllAlbums()).thenReturn([]);
        when(() => mockRepository.count).thenReturn(0);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(const DeleteAlbum('album-001')),
      expect: () => [
        CollectionLoading(),
        const CollectionLoaded(albums: [], totalCount: 0),
      ],
      verify: (bloc) {
        verify(() => mockRepository.deleteAlbum('album-001')).called(1);
        verify(() => mockRepository.getAllAlbums()).called(1);
      },
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionError] when delete fails',
      build: () {
        when(() => mockRepository.deleteAlbum('album-001')).thenThrow(Exception('Delete failed'));
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(const DeleteAlbum('album-001')),
      expect: () => [
        const CollectionError('Exception: Delete failed'),
      ],
    );
  });

  // ---------------------------------------------------------------
  // ToggleFavorite
  // ---------------------------------------------------------------
  group('ToggleFavorite', () {
    blocTest<CollectionBloc, CollectionState>(
      'toggles favorite and reloads collection',
      build: () {
        final album = AlbumFactory.create(id: 'album-001');
        when(() => mockRepository.getAllAlbums()).thenReturn([album]);
        when(() => mockRepository.updateAlbum(any())).thenAnswer((_) async {});
        when(() => mockRepository.count).thenReturn(1);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(const ToggleFavorite('album-001')),
      expect: () => [
        CollectionLoading(),
        CollectionLoaded(
          albums: [AlbumFactory.create(id: 'album-001')],
          totalCount: 1,
        ),
      ],
      verify: (bloc) {
        verify(() => mockRepository.updateAlbum(any())).called(1);
      },
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionError] when album not found for toggle',
      build: () {
        // getAllAlbums returns a list that does NOT contain the target id
        final otherAlbum = AlbumFactory.create(id: 'other-album');
        when(() => mockRepository.getAllAlbums()).thenReturn([otherAlbum]);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(const ToggleFavorite('nonexistent-id')),
      expect: () => [
        isA<CollectionError>(),
      ],
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionError] when updateAlbum fails during toggle',
      build: () {
        final album = AlbumFactory.create(id: 'album-001');
        when(() => mockRepository.getAllAlbums()).thenReturn([album]);
        when(() => mockRepository.updateAlbum(any())).thenThrow(Exception('Update failed'));
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(const ToggleFavorite('album-001')),
      expect: () => [
        isA<CollectionError>(),
      ],
    );
  });

  // ---------------------------------------------------------------
  // AddAlbum
  // ---------------------------------------------------------------
  group('AddAlbum', () {
    blocTest<CollectionBloc, CollectionState>(
      'adds album and reloads collection',
      build: () {
        final album = AlbumFactory.create();
        when(() => mockRepository.addAlbum(album)).thenAnswer((_) async => album);
        when(() => mockRepository.getAllAlbums()).thenReturn([album]);
        when(() => mockRepository.count).thenReturn(1);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(AddAlbum(AlbumFactory.create())),
      expect: () => [
        CollectionLoading(),
        isA<CollectionLoaded>(),
      ],
      verify: (bloc) {
        verify(() => mockRepository.addAlbum(any())).called(1);
      },
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionError] when add fails',
      build: () {
        final album = AlbumFactory.create();
        when(() => mockRepository.addAlbum(album)).thenThrow(Exception('Add failed'));
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(AddAlbum(album)),
      expect: () => [
        const CollectionError('Exception: Add failed'),
      ],
    );
  });

  // ---------------------------------------------------------------
  // UpdateAlbum
  // ---------------------------------------------------------------
  group('UpdateAlbum', () {
    blocTest<CollectionBloc, CollectionState>(
      'updates album and reloads collection',
      build: () {
        final album = AlbumFactory.create(title: 'Updated');
        when(() => mockRepository.updateAlbum(album)).thenAnswer((_) async {});
        when(() => mockRepository.getAllAlbums()).thenReturn([album]);
        when(() => mockRepository.count).thenReturn(1);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(UpdateAlbum(AlbumFactory.create(title: 'Updated'))),
      expect: () => [
        CollectionLoading(),
        isA<CollectionLoaded>(),
      ],
    );
  });

  // ---------------------------------------------------------------
  // ClearSearch
  // ---------------------------------------------------------------
  group('ClearSearch', () {
    blocTest<CollectionBloc, CollectionState>(
      'clears search and reloads collection',
      build: () {
        when(() => mockRepository.getAllAlbums()).thenReturn([]);
        when(() => mockRepository.count).thenReturn(0);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(ClearSearch()),
      expect: () => [
        CollectionLoading(),
        const CollectionLoaded(albums: [], totalCount: 0),
      ],
    );
  });

  // ---------------------------------------------------------------
  // ExportCollection
  // ---------------------------------------------------------------
  group('ExportCollection', () {
    blocTest<CollectionBloc, CollectionState>(
      'exports collection and emits loaded state with exportPath',
      build: () {
        when(() => mockRepository.exportToJson()).thenAnswer((_) async => '/path/to/export.json');
        when(() => mockRepository.getAllAlbums()).thenReturn([]);
        when(() => mockRepository.count).thenReturn(0);
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(ExportCollection()),
      expect: () => [
        const CollectionLoaded(
          albums: [],
          totalCount: 0,
          exportPath: '/path/to/export.json',
        ),
      ],
    );

    blocTest<CollectionBloc, CollectionState>(
      'emits [CollectionError] when export fails',
      build: () {
        when(() => mockRepository.exportToJson()).thenThrow(Exception('Export failed'));
        return CollectionBloc(mockRepository);
      },
      act: (bloc) => bloc.add(ExportCollection()),
      expect: () => [
        const CollectionError('Exception: Export failed'),
      ],
    );
  });

  // ---------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------
  group('initial state', () {
    test('initial state is CollectionInitial', () {
      final bloc = CollectionBloc(mockRepository);
      expect(bloc.state, isA<CollectionInitial>());
    });
  });
}
