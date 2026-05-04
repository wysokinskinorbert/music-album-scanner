import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_album_scanner/core/network/api_client.dart';
import 'package:music_album_scanner/data/services/api/musicbrainz_service.dart';

class MockApiClient extends Mock implements ApiClient {}

class FakeResponse<T> extends Fake implements Response<T> {}

void main() {
  group('MusicBrainzService', () {
    late MusicBrainzService service;
    late MockApiClient mockClient;

    setUpAll(() {
      registerFallbackValue(FakeResponse<Map<String, dynamic>>());
    });

    setUp(() {
      mockClient = MockApiClient();
      service = MusicBrainzService(mockClient);
    });

    // ---------------------------------------------------------------
    // searchRelease – search by artist+title query
    // ---------------------------------------------------------------
    group('searchRelease', () {
      test('returns list of releases on successful response', () async {
        final responseData = {
          'releases': [
            {
              'id': 'mb-001',
              'title': 'Kind of Blue',
              'artist-credit': [
                {'name': 'Miles Davis', 'artist': {'name': 'Miles Davis'}},
              ],
              'date': '1959-08-17',
              'country': 'US',
            },
            {
              'id': 'mb-002',
              'title': 'A Love Supreme',
              'artist-credit': [
                {'name': 'John Coltrane', 'artist': {'name': 'John Coltrane'}},
              ],
              'date': '1965-02-01',
              'country': 'US',
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

        final results = await service.searchRelease(
          query: 'artist:Miles Davis AND release:Kind of Blue',
        );

        expect(results, isA<List<Map<String, dynamic>>>());
        expect(results.length, 2);
        expect(results[0]['title'], 'Kind of Blue');
        expect(results[1]['title'], 'A Love Supreme');
      });

      test('returns empty list when no releases found', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'releases': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final results = await service.searchRelease(query: 'nonexistent');

        expect(results, isEmpty);
      });

      test('returns empty list when releases key is null', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: <String, dynamic>{},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final results = await service.searchRelease(query: 'test');

        expect(results, isEmpty);
      });

      test('passes correct query parameters', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'releases': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        await service.searchRelease(query: 'test query', limit: 10);

        final captured = verify(() => mockClient.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
            )).captured;

        final params = captured.first as Map<String, dynamic>;
        expect(params['query'], 'test query');
        expect(params['fmt'], 'json');
        expect(params['limit'], 10);
      });

      test('uses default limit of 5', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'releases': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        await service.searchRelease(query: 'test');

        final captured = verify(() => mockClient.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
            )).captured;

        final params = captured.first as Map<String, dynamic>;
        expect(params['limit'], 5);
      });

      test('throws DioException on network error', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.connectionError,
            ));

        expect(
          () => service.searchRelease(query: 'test'),
          throwsA(isA<DioException>()),
        );
      });
    });

    // ---------------------------------------------------------------
    // searchByBarcode
    // ---------------------------------------------------------------
    group('searchByBarcode', () {
      test('searches by barcode and returns releases', () async {
        final responseData = {
          'releases': [
            {
              'id': 'mb-barcode-001',
              'title': 'Abbey Road',
              'barcode': '0074640602228',
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

        final results = await service.searchByBarcode('0074640602228');

        expect(results.length, 1);
        expect(results[0]['title'], 'Abbey Road');
      });

      test('passes barcode: prefix in query', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'releases': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        await service.searchByBarcode('12345678');

        final captured = verify(() => mockClient.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
            )).captured;

        final params = captured.first as Map<String, dynamic>;
        expect(params['query'], 'barcode:12345678');
        expect(params['limit'], 1);
      });

      test('returns empty list for unrecognized barcode', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: {'releases': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final results = await service.searchByBarcode('0000000000');

        expect(results, isEmpty);
      });
    });

    // ---------------------------------------------------------------
    // getReleaseDetails
    // ---------------------------------------------------------------
    group('getReleaseDetails', () {
      test('returns detailed release data', () async {
        final responseData = {
          'id': 'mb-001',
          'title': 'Kind of Blue',
          'media': [
            {
              'tracks': [
                {'title': 'So What', 'position': '1'},
                {'title': 'Freddie Freeloader', 'position': '2'},
              ],
            },
          ],
          'label-info-list': [
            {'label': {'name': 'Columbia Records'}},
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

        final result = await service.getReleaseDetails('mb-001');

        expect(result, isNotNull);
        expect(result!['title'], 'Kind of Blue');
      });

      test('returns null when response data is null', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response(
              data: null,
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final result = await service.getReleaseDetails('nonexistent');

        expect(result, isNull);
      });
    });

    // ---------------------------------------------------------------
    // getCoverArtUrl
    // ---------------------------------------------------------------
    group('getCoverArtUrl', () {
      test('returns cover art URL when images exist', () async {
        final responseData = {
          'images': [
            {'image': 'https://coverartarchive.org/release/mb-001/front.jpg'},
          ],
        };

        when(() => mockClient.get(any())).thenAnswer((_) async => Response(
              data: responseData,
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final url = await service.getCoverArtUrl('mb-001');

        expect(url, 'https://coverartarchive.org/release/mb-001/front.jpg');
      });

      test('returns null when images list is empty', () async {
        when(() => mockClient.get(any())).thenAnswer((_) async => Response(
              data: {'images': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final url = await service.getCoverArtUrl('mb-001');

        expect(url, isNull);
      });

      test('returns null when response data is null', () async {
        when(() => mockClient.get(any())).thenAnswer((_) async => Response(
              data: null,
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

        final url = await service.getCoverArtUrl('mb-001');

        expect(url, isNull);
      });

      test('returns null on error (cover art may not exist)', () async {
        when(() => mockClient.get(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.badResponse,
        ));

        final url = await service.getCoverArtUrl('mb-001');

        expect(url, isNull);
      });
    });

    // ---------------------------------------------------------------
    // parseRelease
    // ---------------------------------------------------------------
    group('parseRelease', () {
      test('parses full release with all fields', () {
        final release = {
          'id': 'mb-001',
          'title': 'Kind of Blue',
          'artist-credit': [
            {'name': 'Miles Davis', 'artist': {'name': 'Miles Davis'}},
          ],
          'date': '1959-08-17',
          'country': 'US',
          'label-info-list': [
            {'label': {'name': 'Columbia Records'}},
          ],
          'media': [
            {
              'tracks': [
                {'title': 'So What'},
                {'title': 'Freddie Freeloader'},
                {'title': 'Blue in Green'},
              ],
            },
          ],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['musicBrainzId'], 'mb-001');
        expect(parsed['title'], 'Kind of Blue');
        expect(parsed['artist'], 'Miles Davis');
        expect(parsed['releaseYear'], 1959);
        expect(parsed['label'], 'Columbia Records');
        expect(parsed['country'], 'US');
        expect(parsed['tracklist'], ['So What', 'Freddie Freeloader', 'Blue in Green']);
      });

      test('handles missing artist-credit gracefully', () {
        final release = {
          'id': 'mb-002',
          'title': 'Unknown Album',
        };

        final parsed = service.parseRelease(release);

        expect(parsed['artist'], 'Unknown');
        expect(parsed['title'], 'Unknown Album');
        expect(parsed['releaseYear'], isNull);
        expect(parsed['tracklist'], isEmpty);
        expect(parsed['label'], isEmpty);
      });

      test('parses date with only year', () {
        final release = {
          'id': 'mb-003',
          'title': 'Test',
          'date': '1975',
        };

        final parsed = service.parseRelease(release);

        expect(parsed['releaseYear'], 1975);
      });

      test('parses date with short format gracefully', () {
        final release = {
          'id': 'mb-004',
          'title': 'Test',
          'date': '99',
        };

        final parsed = service.parseRelease(release);

        // int.tryParse('99') = 99, so it will be 99
        expect(parsed['releaseYear'], 99);
      });

      test('handles empty date', () {
        final release = {
          'id': 'mb-005',
          'title': 'Test',
          'date': '',
        };

        final parsed = service.parseRelease(release);

        expect(parsed['releaseYear'], isNull);
      });

      test('handles null date', () {
        final release = <String, dynamic>{
          'id': 'mb-006',
          'title': 'Test',
        };

        final parsed = service.parseRelease(release);

        expect(parsed['releaseYear'], isNull);
      });

      test('falls back to artist name from nested artist object', () {
        final release = {
          'id': 'mb-007',
          'title': 'Test Album',
          'artist-credit': [
            {
              'artist': {'name': 'Fallback Artist'},
            },
          ],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['artist'], 'Fallback Artist');
      });

      test('extracts tracks from multiple media', () {
        final release = {
          'id': 'mb-008',
          'title': 'Double Album',
          'media': [
            {
              'tracks': [
                {'title': 'Disc 1 Track 1'},
                {'title': 'Disc 1 Track 2'},
              ],
            },
            {
              'tracks': [
                {'title': 'Disc 2 Track 1'},
              ],
            },
          ],
        };

        final parsed = service.parseRelease(release);

        expect(parsed['tracklist'], [
          'Disc 1 Track 1',
          'Disc 1 Track 2',
          'Disc 2 Track 1',
        ]);
      });

      test('handles null title gracefully', () {
        final release = <String, dynamic>{
          'id': 'mb-009',
        };

        final parsed = service.parseRelease(release);

        expect(parsed['title'], 'Unknown');
      });
    });

    // ---------------------------------------------------------------
    // Error / rate limiting behavior via ApiClient
    // ---------------------------------------------------------------
    group('error handling', () {
      test('propagates DioException on 429 too many requests', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.badResponse,
              response: Response(
                statusCode: 429,
                requestOptions: RequestOptions(path: ''),
              ),
            ));

        expect(
          () => service.searchRelease(query: 'test'),
          throwsA(isA<DioException>()),
        );
      });

      test('propagates DioException on connection timeout', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.connectionTimeout,
            ));

        expect(
          () => service.searchRelease(query: 'test'),
          throwsA(isA<DioException>()),
        );
      });

      test('propagates generic exception from ApiClient', () async {
        when(() => mockClient.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(Exception('Unexpected error'));

        expect(
          () => service.searchRelease(query: 'test'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
