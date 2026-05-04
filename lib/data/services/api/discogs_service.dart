import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';

/// Discogs API integration as fallback for album recognition.
class DiscogsService {
  final ApiClient _client;
  String? _token;

  DiscogsService(this._client);

  void setToken(String token) => _token = token;

  /// Search database by query string.
  Future<List<Map<String, dynamic>>> search({
    required String query,
    String type = 'release',
    int perPage = 5,
  }) async {
    final queryParams = {
      'q': query,
      'type': type,
      'per_page': perPage,
    };
    if (_token != null) {
      queryParams['token'] = _token;
    }

    final response = await _client.get(
      '${AppConstants.discogsBaseUrl}/database/search',
      queryParameters: queryParams,
    );

    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  /// Get detailed release information.
  Future<Map<String, dynamic>?> getRelease(int releaseId) async {
    final response = await _client.get(
      '${AppConstants.discogsBaseUrl}/releases/$releaseId',
    );
    return response.data as Map<String, dynamic>?;
  }

  /// Parse Discogs release into standardized format.
  Map<String, dynamic> parseRelease(Map<String, dynamic> release) {
    final tracklist = <String>[];
    final rawTracklist = release['tracklist'] as List<dynamic>? ?? [];
    for (final track in rawTracklist) {
      tracklist.add(track['title'] as String? ?? '');
    }

    final artists = release['artists'] as List<dynamic>? ?? [];
    final artistName = artists.isNotEmpty
        ? (artists[0]['name'] ?? 'Unknown')
        : 'Unknown';

    final year = int.tryParse(release['year']?.toString() ?? '');

    final genres = release['genres'] as List<dynamic>? ?? [];
    final styles = release['styles'] as List<dynamic>? ?? [];
    final genre = [...genres, ...styles].join(', ');

    return {
      'discogsId': release['id']?.toString(),
      'title': release['title'] ?? 'Unknown',
      'artist': artistName,
      'releaseYear': year,
      'label': (release['labels'] as List<dynamic>? ?? [])
          .map((l) => l['name'] ?? '')
          .join(', '),
      'genre': genre.isNotEmpty ? genre : null,
      'country': release['country'],
      'tracklist': tracklist,
      'coverArtUrl': release['images']?.isNotEmpty == true
          ? release['images'][0]['uri']
          : null,
    };
  }
}
