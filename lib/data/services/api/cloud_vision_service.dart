import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudVisionService {
  String? _apiKey;
  static const int _monthlyLimit = 1000;
  static const String _keyPref = 'cloud_vision_api_key';
  static const String _usageMonthPref = 'cloud_vision_usage_month';
  static const String _usageCountPref = 'cloud_vision_usage_count';

  String? get apiKey => _apiKey;
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_keyPref);
    // Reset counter if new month
    final currentMonth = '${DateTime.now().year}-${DateTime.now().month}';
    final savedMonth = prefs.getString(_usageMonthPref);
    if (savedMonth != currentMonth) {
      await prefs.setString(_usageMonthPref, currentMonth);
      await prefs.setInt(_usageCountPref, 0);
    }
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key);
  }

  Future<void> clearApiKey() async {
    _apiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPref);
  }

  int get monthlyLimit => _monthlyLimit;

  Future<int> getUsedThisMonth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_usageCountPref) ?? 0;
  }

  Future<int> getRemainingQuota() async {
    return _monthlyLimit - await getUsedThisMonth();
  }

  Future<void> _incrementUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_usageCountPref) ?? 0;
    await prefs.setInt(_usageCountPref, current + 1);
  }

  /// Identify an album cover image using Google Cloud Vision.
  /// Returns a map with 'artist' and 'title' keys, or null if not found.
  Future<Map<String, String>?> identifyAlbumCover(String imagePath) async {
    if (!isConfigured) return null;
    final remaining = await getRemainingQuota();
    if (remaining <= 0) {
      debugPrint('[CloudVision] Quota exhausted for this month!');
      return null;
    }

    try {
      // Read and base64 encode the image
      final file = File(imagePath);
      if (!await file.exists()) return null;

      // Resize to max 640px to save quota (Cloud Vision charges per image)
      final bytes = await _resizeImage(file, maxWidth: 640);
      final base64Image = base64Encode(bytes);

      final url = 'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';

      final requestBody = jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'WEB_DETECTION', 'maxResults': 10},
              {'type': 'LABEL_DETECTION', 'maxResults': 10},
            ],
          },
        ],
      });

      debugPrint('[CloudVision] Sending request (remaining quota: $remaining)...');

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/json');
      request.write(requestBody);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      await _incrementUsage();

      if (response.statusCode != 200) {
        debugPrint('[CloudVision] ERROR: status ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final responses = data['responses'] as List<dynamic>?;
      if (responses == null || responses.isEmpty) return null;

      final result = responses[0] as Map<String, dynamic>;

      // Extract album info from web detection
      final webDetection = result['webDetection'] as Map<String, dynamic>?;
      if (webDetection != null) {
        // Check web entities for album/artist clues
        final entities =
            webDetection['webEntities'] as List<dynamic>? ?? [];
        debugPrint(
            '[CloudVision] Web entities: ${entities.map((e) => e['description']).toList()}');

        String? artist;
        String? title;

        for (final entity in entities) {
          final desc = entity['description']?.toString() ?? '';
          final score = entity['score'] as double? ?? 0;
          if (score < 0.5) continue;

          // Try to parse 'Artist - Title' or 'Artist Title Album' patterns
          if (desc.contains(' album') || desc.contains('Album')) {
            // e.g. 'OK Computer album' -> extract
            final cleaned = desc.replaceAll(
                RegExp(r'\b(album|cover|art|artwork)\b',
                    caseSensitive: false),
                '').trim();
            if (cleaned.contains(' - ')) {
              final parts = cleaned.split(' - ');
              artist ??= parts[0].trim();
              title ??= parts.sublist(1).join(' - ').trim();
            } else {
              // Single entity - might be artist or album name
              if (artist == null) {
                artist = cleaned;
              } else if (title == null) {
                title = cleaned;
              }
            }
          }

          // Check for 'Artist - Title' in description
          if (desc.contains(' - ') && artist == null) {
            final parts = desc.split(' - ');
            if (parts.length == 2 &&
                parts[0].length > 1 &&
                parts[1].length > 1) {
              artist = parts[0].trim();
              title = parts[1].trim();
            }
          }
        }

        // Also check pagesWithMatchingImages for clues
        final pages =
            webDetection['pagesWithMatchingImages'] as List<dynamic>? ?? [];
        for (final page in pages.take(5)) {
          final pageTitle = page['pageTitle']?.toString() ?? '';
          debugPrint('[CloudVision] Page: $pageTitle');
          if (pageTitle.contains(' - ') && artist == null) {
            final parts = pageTitle.split(' - ');
            if (parts.length >= 2) {
              // Clean up page title (remove site names)
              final potentialArtist =
                  parts[0].replaceAll(RegExp(r'\|.*'), '').trim();
              final potentialTitle =
                  parts[1].replaceAll(RegExp(r'\|.*'), '').trim();
              if (potentialArtist.length > 1 && potentialTitle.length > 1) {
                artist = potentialArtist;
                title = potentialTitle;
              }
            }
          }
        }

        if (artist != null || title != null) {
          debugPrint('[CloudVision] FOUND: artist=$artist, title=$title');
          return {
            'artist': artist ?? '',
            'title': title ?? '',
          };
        }
      }

      // Fallback: use labels to construct a search query
      final labelAnnotations =
          result['labelAnnotations'] as List<dynamic>? ?? [];
      if (labelAnnotations.isNotEmpty) {
        final labels = labelAnnotations
            .where((l) => (l['score'] as double? ?? 0) > 0.7)
            .map((l) => l['description'].toString())
            .toList();
        debugPrint('[CloudVision] Labels: $labels');
        // Return labels as a query hint
        if (labels.isNotEmpty) {
          return {'query': labels.join(' ')};
        }
      }

      debugPrint('[CloudVision] No album match found');
      return null;
    } catch (e) {
      debugPrint('[CloudVision] ERROR: $e');
      return null;
    }
  }

  /// Resize image to save API quota
  Future<Uint8List> _resizeImage(File file, {int maxWidth = 640}) async {
    final bytes = await file.readAsBytes();
    // For simplicity, just use original bytes if small enough
    // In production, use the image package to resize
    if (bytes.length < 500000) return bytes; // Under 500KB, send as-is

    try {
      // Use dart:ui to decode and resize
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      if (image.width <= maxWidth) return bytes;

      final ratio = maxWidth / image.width;
      final newHeight = (image.height * ratio).round();

      final recorder = PictureRecorder();
      final canvas = Canvas(
          recorder,
          Rect.fromLTWH(
              0, 0, maxWidth.toDouble(), newHeight.toDouble()));
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
            0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
            0, 0, maxWidth.toDouble(), newHeight.toDouble()),
        Paint(),
      );

      final picture = recorder.endRecording();
      final resized = await picture.toImage(maxWidth, newHeight);
      final pngBytes =
          await resized.toByteData(format: ImageByteFormat.png);

      return pngBytes!.buffer.asUint8List();
    } catch (e) {
      debugPrint('[CloudVision] Resize failed, using original: $e');
      return bytes;
    }
  }
}
