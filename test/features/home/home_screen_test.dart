import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_album_scanner/features/home/home_screen.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_bloc.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_event.dart';
import 'package:music_album_scanner/features/collection/bloc/collection_state.dart';
import 'package:music_album_scanner/core/theme/app_theme.dart';

class MockCollectionBloc extends Mock implements CollectionBloc {}

void main() {
  late MockCollectionBloc mockCollectionBloc;

  setUp(() {
    mockCollectionBloc = MockCollectionBloc();
    // Default: loaded with empty collection
    when(() => mockCollectionBloc.state).thenReturn(
      const CollectionLoaded(albums: [], totalCount: 0),
    );
    when(() => mockCollectionBloc.stream).thenReturn(
      Stream.value(const CollectionLoaded(albums: [], totalCount: 0)),
    );
  });

  Widget createTestWidget() {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<CollectionBloc>.value(
        value: mockCollectionBloc,
        child: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen', () {
    testWidgets('renders bottom navigation with tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have bottom navigation bar
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('shows Collection tab label', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Collection'), findsWidgets);
    });

    testWidgets('shows Settings tab label', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('loads collection on init', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      verify(() => mockCollectionBloc.add(any(that: isA<LoadCollection>()))).called(1);
    });
  });
}
