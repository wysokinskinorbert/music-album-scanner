import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_album_scanner/features/collection/collection_screen.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_bloc.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_event.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_state.dart';
import 'package:music_album_scanner/core/theme/app_theme.dart';
import 'package:music_album_scanner/data/models/album_model.dart';

class MockCollectionBloc extends Mock implements CollectionBloc {}

void main() {
  late MockCollectionBloc mockCollectionBloc;

  setUp(() {
    mockCollectionBloc = MockCollectionBloc();
  });

  Widget createTestWidget() {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<CollectionBloc>.value(
        value: mockCollectionBloc,
        child: const CollectionScreen(),
      ),
    );
  }

  group('CollectionScreen', () {
    testWidgets('shows empty state when no albums', (tester) async {
      when(() => mockCollectionBloc.state).thenReturn(
        const CollectionLoaded(albums: [], totalCount: 0),
      );
      when(() => mockCollectionBloc.stream).thenReturn(
        Stream.value(const CollectionLoaded(albums: [], totalCount: 0)),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Empty state should be visible
      expect(find.text('No albums yet'), findsOneWidget);
    });

    testWidgets('shows album count in header', (tester) async {
      final albums = List.generate(
        3,
        (i) => AlbumModel(
          id: 'album_\$i',
          title: 'Album \$i',
          artist: 'Artist \$i',
          releaseYear: 2020 + i,
        ),
      );
      when(() => mockCollectionBloc.state).thenReturn(
        CollectionLoaded(albums: albums, totalCount: albums.length),
      );
      when(() => mockCollectionBloc.stream).thenReturn(
        Stream.value(CollectionLoaded(albums: albums, totalCount: albums.length)),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows loading state', (tester) async {
      when(() => mockCollectionBloc.state).thenReturn(
        const CollectionLoading(),
      );
      when(() => mockCollectionBloc.stream).thenReturn(
        Stream.value(const CollectionLoading()),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      when(() => mockCollectionBloc.state).thenReturn(
        const CollectionError('Failed to load'),
      );
      when(() => mockCollectionBloc.stream).thenReturn(
        Stream.value(const CollectionError('Failed to load')),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button triggers LoadCollection', (tester) async {
      when(() => mockCollectionBloc.state).thenReturn(
        const CollectionError('Failed to load'),
      );
      when(() => mockCollectionBloc.stream).thenReturn(
        Stream.value(const CollectionError('Failed to load')),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => mockCollectionBloc.add(any(that: isA<LoadCollection>()))).called(greaterThanOrEqualTo(1));
    });
  });
}
