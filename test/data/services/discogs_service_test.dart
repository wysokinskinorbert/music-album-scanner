import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_album_scanner/core/network/api_client.dart';
import 'package:music_album_scanner/data/services/api/discogs_service.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('DiscogsService', () {
    late DiscogsService service;
    late MockApiClient mockClient;

    setUp(() {
      mockClient = MockApiClient();
      service = DiscogsService(mockClient);
    });

    // ---------------------------------------------------------------
    // search
    // ---------------------------------------------------------------
    group('search', () {
      test('returns list of results on successful response', () async {
        final responseData = {
          'results': [
            {
              'id': 12345,
              'title': 'Miles Davis - Kind of Blue',
              'type': 'release',
              'year': '1959',
            },
            {
              'id': 67890,
              'title': 'John Coltrane - A Love Supreme',
              'type': 'release',
              'year': '1965',
            },
          ],
        };

        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: responseData,
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final results = await service.search(query: 'Kind of Blue');

        expect(results, isA<List<Map<String, dynamic>>>());
        expect(results.length, 2);
        expect(results[0]['title'], 'Miles Davis - Kind of Blue');
        expect(results[1]['title'], 'John Coltrane - A Love Supreme');
      });

      test('returns empty list when no results found', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'results': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final results = await service.search(query: 'nonexistent');

        expect(results, isEmpty);
      });

      test('returns empty list when results key is null', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: <String, dynamic>{},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final results = await service.search(query: 'test');

        expect(results, isEmpty);
      });

      test('passes correct default query parameters', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'results': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        await service.search(query: 'test query');

        final captured = verify(() => mockClient.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
            )).captured;

        final params = captured.first as Map<String, dynamic>;
        expect(params['q'], 'test query');
        expect(params['type'], 'release');
        expect(params['per_page'], 5);
      });

      test('accepts custom type and perPage', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'results': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        await service.search(query: 'test', type: 'master', perPage: 10);

        final captured = verify(() => mockClient.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
            )).captured;

        final params = captured.first as Map<String, dynamic>;
        expect(params['type'], 'master');
        expect(params['per_page'], 10);
      });
    });

    // ---------------------------------------------------------------
    // Auth token handling
    // ---------------------------------------------------------------
    group('auth token', () {
      test('includes token in query params when set', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'results': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        service.setToken('my-secret-token');
        await service.search(query: 'test');

        final captured = verify(() => mockClient.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
            )).captured;

        final params = captured.first as Map<String, dynamic>;
        expect(params['token'], 'my-secret-token');
      });

      test('does not include token when not set', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'results': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        // Do NOT call setToken — token is null by default
        await service.search(query: 'test');

        final captured = verify(() => mockClient.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
            )).captured;

        final params = captured.first as Map<String, dynamic>;
        expect(params.containsKey('token'), isFalse);
      });

      test('token persists across multiple calls', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'results': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        service.setToken('persistent-token');
        await service.search(query: 'first');
        await service.search(query: 'second');

        verify(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).called(2);

        // Both calls should include the token
        final allCaptured = verify(() => mockClient.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
            )).captured;

        for (final captured in allCaptured) {
          final params = captured as Map<String, dynamic>;
          expect(params['token'], 'persistent-token');
        }
      });
    });

    // ---------------------------------------------------------------
    // getRelease
    // ---------------------------------------------------------------
    group('getRelease', () {
      test('returns detailed release data', () async {
        final responseData = {
          'id': 12345,
          'title': 'Kind of Blue',
          'artists': [{'name': 'Miles Davis'}],
          'year': '1959',
          'tracklist': [
            {'title': 'So What', 'position': '1'},
            {'title': 'Freddie Freeloader', 'position': '2'},
          ],
        };

        when(() => mockClient.get(any())).thenAnswer((_) async => Response(
              data: responseData,
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final result = await service.getRelease(12345);

        expect(result, isNotNull);
        expect(result!['title'], 'Kind of Blue');
        expect(result['artists'].length, 1);
      });

      test('returns null when response data is null', () async {
        when(() => mockClient.get(any())).thenAnswer((_) async => Response(
              data: null,
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final result = await service.getRelease(99999);

        expect(result, isNull);
      });
    });

    // ---------------------------------------------------------------
    // parseRelease
    // ---------------------------------------------------------------
    group('parseRelease', () {
      test('parses full release with all fields', () {
        final release = {
          'id': 12345,
          'title': 'Kind of Blue',
          'artists': [
            {'name': 'Miles Davis'},
          ],
          'year': '1959',
          'labels': [
            {'name': 'Columbia Records'},
            {'name': 'Columbia'},
          ],
          'genres': ['Jazz'],
          'styles': ['Modal', 'Hard Bop'],
          'country': 'US',
          'tracklist': [
            {'title': 'So What'},
            {'title': 'Freddie Freeloader'},
            {'title': 'Blue in Green'},
          ],
          'images': [
            {'uri': 'https://img.discogs.com/kind_of_blue.jpg'},
          ],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['discogsId'], '12345');
        expect(parsed['title'], 'Kind of Blue');
        expect(parsed['artist'], 'Miles Davis');
        expect(parsed['releaseYear'], 1959);
        expect(parsed['label'], 'Columbia Records, Columbia');
        expect(parsed['genre'], 'Jazz, Modal, Hard Bop');
        expect(parsed['country'], 'US');
        expect(parsed['tracklist'], ['So What', 'Freddie Freeloader', 'Blue in Green']);
        expect(parsed['coverArtUrl'], 'https://img.discogs.com/kind_of_blue.jpg');
      });

      test('handles missing artists gracefully', () {
        final release = <String, dynamic>{
          'id': 99,
          'title': 'Unknown Album',
        };

        final parsed = service.parseRelease(release);

        expect(parsed['artist'], 'Unknown');
        expect(parsed['tracklist'], isEmpty);
      });

      test('handles empty artists list', () {
        final release = <String, dynamic>{
          'id': 99,
          'title': 'No Artist',
          'artists': [],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['artist'], 'Unknown');
      });

      test('handles null year', () {
        final release = <String, dynamic>{
          'id': 99,
          'title': 'Test',
          'artists': [{'name': 'Test'}],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['releaseYear'], isNull);
      });

      test('handles non-numeric year', () {
        final release = <String, dynamic>{
          'id': 99,
          'title': 'Test',
          'year': 'Unknown',
          'artists': [{'name': 'Test'}],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['releaseYear'], isNull);
      });

      test('sets genre to null when genres and styles are empty', () {
        final release = <String, dynamic>{
          'id': 99,
          'title': 'Test',
          'artists': [{'name': 'Test'}],
          'genres': [],
          'styles': [],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['genre'], isNull);
      });

      test('extracts cover art from images', () {
        final release = {
          'id': 99,
          'title': 'Test',
          'images': [
            {'uri': 'https://example.com/cover.jpg'},
          ],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['coverArtUrl'], 'https://example.com/cover.jpg');
      });

      test('sets coverArtUrl to null when no images', () {
        final release = <String, dynamic>{
          'id': 99,
          'title': 'Test',
        };

        final parsed = service.parseRelease(release);

        expect(parsed['coverArtUrl'], isNull);
      });

      test('extracts label names from labels list', () {
        final release = {
          'id': 99,
          'title': 'Test',
          'labels': [
            {'name': 'Label A'},
            {'name': 'Label B'},
          ],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['label'], 'Label A, Label B');
      });

      test('extracts tracklist from raw tracklist', () {
        final release = {
          'id': 99,
          'title': 'Test',
          'tracklist': [
            {'title': 'Track 1'},
            {'title': 'Track 2'},
            {'title': ''}, // empty title
          ],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['tracklist'], ['Track 1', 'Track 2', '']);
      });
    });

    // ---------------------------------------------------------------
    // Error handling
    // ---------------------------------------------------------------
    group('error handling', () {
      test('throws DioException on network error', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.connectionError,
            ));

        expect(
          () => service.search(query: 'test'),
          throwsA(isA<DioException>()),
        );
      });

      test('throws on 401 unauthorized (bad token)', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.badResponse,
              response: Response(
                statusCode: 401,
                requestOptions: RequestOptions(path: ''),
              ),
            ));

        service.setToken('invalid-token');

        expect(
          () => service.search(query: 'test'),
          throwsA(isA<DioException>()),
        );
      });

      test('throws generic exception from ApiClient', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(Exception('Unexpected error'));

        expect(
          () => service.search(query: 'test'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
