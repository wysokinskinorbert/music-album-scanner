import 'package:test/test.dart';
import 'package:music_album_scanner/core/errors/exceptions.dart';

void main() {
  group('NetworkException', () {
    test('noConnection factory', () {
      final e = NetworkException.noConnection();
      expect(e.message, contains('No internet'));
      expect(e.isNoConnection, isTrue);
      expect(e.isTimeout, isFalse);
      expect(e.isRateLimited, isFalse);
    });

    test('timeout factory', () {
      final e = NetworkException.timeout();
      expect(e.isTimeout, isTrue);
      expect(e.isNoConnection, isFalse);
    });

    test('httpError factory', () {
      final e = NetworkException.httpError(404, body: 'not found');
      expect(e.statusCode, 404);
      expect(e.code, 'HTTP_404');
    });

    test('rateLimited factory with retryAfter', () {
      final e = NetworkException.rateLimited(retryAfter: 30);
      expect(e.isRateLimited, isTrue);
      expect(e.statusCode, 429);
      expect(e.message, contains('30'));
    });

    test('toString includes code', () {
      final e = NetworkException.noConnection();
      expect(e.toString(), contains('NO_CONNECTION'));
    });
  });

  group('ApiException', () {
    test('parseError factory', () {
      final e = ApiException.parseError('musicbrainz');
      expect(e.service, 'musicbrainz');
      expect(e.code, 'PARSE_ERROR');
    });

    test('noResults factory', () {
      final e = ApiException.noResults('discogs');
      expect(e.code, 'NO_RESULTS');
      expect(e.service, 'discogs');
    });

    test('serviceUnavailable factory', () {
      final e = ApiException.serviceUnavailable('coverart');
      expect(e.code, 'SERVICE_UNAVAILABLE');
    });
  });

  group('StorageException', () {
    test('writeError factory', () {
      final e = StorageException.writeError();
      expect(e.code, 'WRITE_ERROR');
    });

    test('readError factory', () {
      final e = StorageException.readError();
      expect(e.code, 'READ_ERROR');
    });

    test('deleteError factory', () {
      final e = StorageException.deleteError();
      expect(e.code, 'DELETE_ERROR');
    });

    test('boxNotOpen factory', () {
      final e = StorageException.boxNotOpen('albums');
      expect(e.message, contains('albums'));
      expect(e.code, 'BOX_NOT_OPEN');
    });
  });

  group('RecognitionException', () {
    test('stageFailed factory', () {
      final e = RecognitionException.stageFailed('ocr');
      expect(e.stage, 'ocr');
      expect(e.code, 'STAGE_FAILED');
    });

    test('noAlbumFound factory', () {
      final e = RecognitionException.noAlbumFound();
      expect(e.stage, 'all');
      expect(e.code, 'NO_ALBUM_FOUND');
    });

    test('lowConfidence factory', () {
      final e = RecognitionException.lowConfidence(0.35);
      expect(e.code, 'LOW_CONFIDENCE');
      expect(e.message, contains('35.0%'));
    });

    test('cameraError factory', () {
      final e = RecognitionException.cameraError();
      expect(e.stage, 'camera');
      expect(e.code, 'CAMERA_ERROR');
    });

    test('imageError factory', () {
      final e = RecognitionException.imageError();
      expect(e.stage, 'image');
    });
  });

  group('PermissionException', () {
    test('camera factory', () {
      final e = PermissionException.camera();
      expect(e.permission, 'camera');
      expect(e.code, 'CAMERA_DENIED');
    });

    test('storage factory', () {
      final e = PermissionException.storage();
      expect(e.permission, 'storage');
    });

    test('photos factory', () {
      final e = PermissionException.photos();
      expect(e.permission, 'photos');
    });
  });

  group('AppException base', () {
    test('toString without code', () {
      const e = StorageException(message: 'test error');
      expect(e.toString(), equals('StorageException: test error'));
    });

    test('toString with code', () {
      const e = StorageException(message: 'test error', code: 'TEST');
      expect(e.toString(), contains('(TEST)'));
    });

    test('preserves originalError and stackTrace', () {
      final original = Exception('original');
      final st = StackTrace.current;
      final e = NetworkException(
        message: 'wrapped',
        originalError: original,
        stackTrace: st,
      );
      expect(e.originalError, original);
      expect(e.stackTrace, st);
    });
  });
}
