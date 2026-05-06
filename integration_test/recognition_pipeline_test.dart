import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:music_album_scanner/core/network/api_client.dart';
import 'package:music_album_scanner/data/services/api/musicbrainz_service.dart';
import 'package:music_album_scanner/data/services/api/discogs_service.dart';
import 'package:music_album_scanner/data/services/api/cloud_vision_service.dart';
import 'package:music_album_scanner/data/services/ml/barcode_scanning_service.dart';
import 'package:music_album_scanner/data/services/ml/text_extraction_service.dart';
import 'package:music_album_scanner/data/services/ml/paddle_ocr_service.dart';
import 'package:music_album_scanner/data/services/ml/image_labeling_service.dart';
import 'package:music_album_scanner/data/services/recognition_service.dart';

/// Album cover test set - expected results for validation
const Map<String, String> expectedAlbums = {
  '01_Radiohead_OK_Computer.jpg': 'Radiohead - OK Computer',
  '02_Miles_Davis_Kind_of_Blue.jpg': 'Miles Davis - Kind of Blue',
  '03_Daft_Punk_Discovery.jpg': 'Daft Punk - Discovery',
  '04_Nirvana_Nevermind.jpg': 'Nirvana - Nevermind',
  '05_Kendrick_Lamar_To_Pimp_a_Butterfly.jpg': 'Kendrick Lamar - To Pimp a Butterfly',
  '06_Burial_Untrue.jpg': 'Burial - Untrue',
  '07_Bjork_Homogenic.jpg': 'Bjork - Homogenic',
  '08_Black_Sabbath_Paranoid.jpg': 'Black Sabbath - Paranoid',
  '09_Fela_Kuti_Zombie.jpg': 'Fela Kuti - Zombie',
  '10_Sigur_Ros_Agaetis_byrjun.jpg': 'Sigur Ros - Agaetis byrjun',
  '11_Massive_Attack_Mezzanine.jpg': 'Massive Attack - Mezzanine',
  '12_Can_Tago_Mago.jpg': 'Can - Tago Mago',
  '13_Aphex_Twin_SAW_85-92.jpg': 'Aphex Twin - Selected Ambient Works 85-92',
  '14_Fleetwood_Mac_Rumours.jpg': 'Fleetwood Mac - Rumours',
  '15_Boards_of_Canada_MHTRTC.jpg': 'Boards of Canada - Music Has the Right to Children',
  '16_MF_DOOM_Madvillainy.jpg': 'Madvillain - Madvillainy',
  '17_Talking_Heads_Remain_in_Light.jpg': 'Talking Heads - Remain in Light',
  '18_Nusrat_Fateh_Ali_Khan_Mustt_Mustt.jpg': 'Nusrat Fateh Ali Khan - Mustt Mustt',
  '19_Metallica_Master_of_Puppets.jpg': 'Metallica - Master of Puppets',
  '20_King_Gizzard_Nonagon_Infinity.jpg': 'King Gizzard - Nonagon Infinity',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Album Recognition Pipeline Tests', () {
    late RecognitionService recognitionService;
    late PaddleOcrService paddleOcr;

    setUp(() async {
      paddleOcr = PaddleOcrService();
      await paddleOcr.initialize();

      final textExtraction = TextExtractionService(paddleOcr: paddleOcr);
      await textExtraction.initialize();

      recognitionService = RecognitionService(
        apiClient: ApiClient(),
        musicBrainz: MusicBrainzService(ApiClient()),
        discogs: DiscogsService(),
        cloudVision: CloudVisionService(),
        barcodeService: BarcodeScanningService(),
        textExtraction: textExtraction,
        imageLabeler: ImageLabelingService(),
      );
    });

    tearDown(() async {
      paddleOcr.release();
    });

    test('Run full recognition pipeline on all album covers', () async {
      // Try multiple locations - scoped storage on Android 15 restricts /sdcard/
      final locations = [
        '/data/local/tmp/AlbumCovers/test_covers',
        '/data/local/tmp/AlbumCovers',
        '/sdcard/Pictures/AlbumCovers',
        '/sdcard/Download/AlbumCovers',
      ];
      Directory? coversDir;
      for (final loc in locations) {
        final d = Directory(loc);
        if (await d.exists()) {
          coversDir = d;
          break;
        }
      }
      if (coversDir == null) {
        fail('No AlbumCovers directory found! Tried: ${locations.join(", ")}');
      }

      final files = await coversDir.list()
          .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
          .toList();
      files.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));

      print('\n' + '=' * 80);
      print('ALBUM RECOGNITION PIPELINE TEST - ${files.length} covers');
      print('=' * 80);

      int correct = 0;
      int partial = 0;
      int failed = 0;
      final results = <Map<String, dynamic>>[];

      for (final file in files) {
        final filename = file.path.split('/').last;
        final expected = expectedAlbums[filename] ?? 'UNKNOWN';
        final expectedParts = expected.split(' - ');
        final expectedArtist = expectedParts[0].toLowerCase();
        final expectedTitle = expectedParts.length > 1 ? expectedParts[1].toLowerCase() : '';

        print('\n--- Testing: $filename ---');
        print('    Expected: $expected');

        final stopwatch = Stopwatch()..start();
        final result = await recognitionService.recognizeFromImage(file.path);
        stopwatch.stop();

        final duration = stopwatch.elapsedMilliseconds;
        final actualArtist = result.album?.artist ?? '';
        final actualTitle = result.album?.title ?? '';
        final confidence = result.confidence ?? 0.0;
        final source = result.source ?? 'none';

        // Scoring
        bool isCorrect = false;
        bool isPartial = false;
        String matchLevel = 'MISS';

        if (result.state.name == 'success' && result.album != null) {
          final artistLower = actualArtist.toLowerCase();
          final titleLower = actualTitle.toLowerCase();

          // Exact match: artist AND title both match
          if ((artistLower.contains(expectedArtist) || expectedArtist.contains(artistLower)) &&
              (titleLower.contains(expectedTitle) || expectedTitle.contains(titleLower))) {
            isCorrect = true;
            matchLevel = 'EXACT';
          }
          // Partial: only artist OR only title matches
          else if (artistLower.contains(expectedArtist) || expectedArtist.contains(artistLower) ||
              titleLower.contains(expectedTitle) || expectedTitle.contains(titleLower)) {
            isPartial = true;
            matchLevel = 'PARTIAL';
          }
        }

        if (isCorrect) correct++;
        else if (isPartial) partial++;
        else failed++;

        final resultStr = '$actualArtist - $actualTitle';
        print('    Got:      $resultStr');
        print('    Source:   $source | Confidence: ${(confidence * 100).toStringAsFixed(1)}% | ${duration}ms');
        print('    Match:    $matchLevel');

        results.add({
          'file': filename,
          'expected': expected,
          'actual': resultStr,
          'source': source,
          'confidence': confidence,
          'duration_ms': duration,
          'match': matchLevel,
          'state': result.state.name,
        });
      }

      // Summary
      final total = files.length;
      print('\n' + '=' * 80);
      print('SUMMARY');
      print('=' * 80);
      print('Total: $total | Exact: $correct | Partial: $partial | Miss: $failed');
      print('Exact rate:   ${(correct / total * 100).toStringAsFixed(1)}%');
      print('Partial rate: ${(partial / total * 100).toStringAsFixed(1)}%');
      print('Hit rate:     ${((correct + partial) / total * 100).toStringAsFixed(1)}%');

      // Per-source breakdown
      final sourceStats = <String, int>{};
      for (final r in results) {
        final src = r['source'] as String? ?? 'none';
        sourceStats[src] = (sourceStats[src] ?? 0) + 1;
      }
      print('\nSource breakdown:');
      for (final entry in sourceStats.entries) {
        print('  ${entry.key}: ${entry.value}');
      }

      // Detailed results table
      print('\n' + '-' * 80);
      print('${'File'.padRight(45)} | ${'Match'.padRight(7)} | ${'Source'.padRight(10)} | Conf');
      print('-' * 80);
      for (final r in results) {
        final confPct = ((r['confidence'] as double) * 100).toStringAsFixed(0);
        print('${(r['file'] as String).padRight(45)} | ${(r['match'] as String).padRight(7)} | ${(r['source'] as String).padRight(10)} | ${confPct}%');
      }
      print('-' * 80);

      // Write results to a file for later analysis (best-effort, don't fail on permission errors)
      try {
        final resultsFile = File('/data/local/tmp/recognition_test_results.txt');
        final buffer = StringBuffer();
        buffer.writeln('Album Recognition Test Results');
        buffer.writeln('Date: ${DateTime.now().toIso8601String()}');
        buffer.writeln('Total: $total | Exact: $correct | Partial: $partial | Miss: $failed');
        buffer.writeln('');
        for (final r in results) {
          buffer.writeln('${r['file']} | ${r['match']} | ${r['actual']} | ${r['source']} | ${(r['confidence'] * 100).toStringAsFixed(1)}%');
        }
        await resultsFile.writeAsString(buffer.toString());
        print('\nResults written to /data/local/tmp/recognition_test_results.txt');
      } catch (e) {
        print('\nCould not write results file: $e (results are in test output above)');
      }
    }, timeout: const Timeout(Duration(minutes: 15)));
  });
}
