import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';

/// MusicBrainz API integration for album metadata lookup.
class MusicBrainzService {
  final ApiClient _client;

  MusicBrainzService(this._client);

  /// Search releases by artist + album name.
  Future<List<Map<String, dynamic>>> searchRelease({
    required String query,
    int limit = 5,
  }) async {
    final data = await _client.get(
      '/ws/2/release',
      queryParameters: {
        'query': query,
        'fmt': 'json',
        'limit': limit,
      },
    );
    if (data == null) return [];
    final releases = data['releases'] as List<dynamic>? ?? [];
    return releases.cast<Map<String, dynamic>>();
  }

  /// Search by barcode (UPC/EAN).
  Future<List<Map<String, dynamic>>> searchByBarcode(String barcode) async {
    final response = await _client.get(
      AppConstants.musicBrainzBaseUrl,
      queryParameters: {
        'query': 'barcode:$barcode',
        'fmt': 'json',
        'limit': 1,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final releases = data['releases'] as List<dynamic>? ?? [];
    return releases.cast<Map<String, dynamic>>();
  }

  /// Get detailed release info including tracklist.
  Future<Map<String, dynamic>?> getReleaseDetails(String mbid) async {
    final response = await _client.get(
      '${AppConstants.musicBrainzBaseUrl}/release/$mbid',
      queryParameters: {
        'fmt': 'json',
        'inc': 'recordings+labels+release-groups',
      },
    );

    return response.data as Map<String, dynamic>?;
  }

  /// Get cover art URL from Cover Art Archive.
  Future<String?> getCoverArtUrl(String mbid) async {
    try {
      final response = await _client.get(
        '${AppConstants.coverArtArchiveUrl}/release/$mbid',
      );
      final data = response.data as Map<String, dynamic>?;
      final images = data?['images'] as List<dynamic>? ?? [];
      if (images.isNotEmpty) {
        return images[0]['image'] as String?;
      }
    } catch (_) {
      // Cover art may not exist for all releases
    }
    return null;
  }

  /// Parse MusicBrainz release into standardized format.
  Map<String, dynamic> parseRelease(Map<String, dynamic> release) {
    final artistCredit = release['artist-credit'] as List<dynamic>? ?? [];
    final artistName = artistCredit.isNotEmpty
        ? (artistCredit[0]['name'] ?? artistCredit[0]['artist']?['name'] ?? 'Unknown')
        : 'Unknown';

    final date = release['date'] as String? ?? '';
    final year = int.tryParse(date.length >= 4 ? date.substring(0, 4) : date);

    final labelList = release['label-info-list'] as List<dynamic>? ?? [];
    final labelName = labelList.isNotEmpty
        ? (labelList[0]['label']?['name'] ?? '')
        : '';

    final media = release['media'] as List<dynamic>? ?? [];
    final tracks = <String>[];
    for (final medium in media) {
      final trackList = medium['tracks'] as List<dynamic>? ?? [];
      for (final track in trackList) {
        tracks.add(track['title'] as String? ?? '');
      }
    }

    return {
      'musicBrainzId': release['id'],
      'title': release['title'] ?? 'Unknown',
      'artist': artistName,
      'releaseYear': year,
      'label': labelName,
      'country': release['country'],
      'tracklist': tracks,
    };
  }
}
