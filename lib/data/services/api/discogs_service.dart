import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/album_model.dart';

/// Discogs API integration for album recognition and metadata lookup.
class DiscogsService {
  final ApiClient _client;
  String? _token;
  late final Dio _dio;

  DiscogsService._(this._client) {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.discogs.com',
      headers: {'User-Agent': 'MusicAlbumScanner/1.0'},
    ));
  }

  factory DiscogsService([ApiClient? client]) => DiscogsService._(client ?? ApiClient());
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.discogs.com',
      headers: {'User-Agent': 'MusicAlbumScanner/1.0'},
    ));
  }

  void setToken(String token) => _token = token;

  /// Search the Discogs database by query string.
  Future<List<Map<String, dynamic>>> search({
    required String query,
    String type = 'release',
    int perPage = 5,
  }) async {
    final queryParams = <String, dynamic>{
      'q': query,
      'type': type,
      'per_page': perPage,
    };
    if (_token != null) {
      queryParams['token'] = _token;
    }

    final response = await _dio.get(
      '/database/search',
      queryParameters: queryParams,
    );

    final data = response as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  /// Search for releases matching [query], optionally filtered by [artist].
  /// Returns a list of [Album] objects parsed from Discogs results.
  Future<List<Album>> searchRelease(String query, {String? artist}) async {
    final fullQuery = artist != null && artist.isNotEmpty
        ? '$artist $query'
        : query;

    final results = await search(query: fullQuery);

    return results.map((r) {
      final year = int.tryParse(r['year']?.toString() ?? '');
      return Album(
        id: 'discogs_${r['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        title: r['title'] ?? 'Unknown',
        artist: _extractArtist(r) ?? 'Unknown',
        releaseYear: year,
        discogsId: r['id']?.toString(),
        coverArtUrl: r['cover_image'] as String?,
        dateAdded: DateTime.now(),
        recognitionConfidence: 0.0,
      );
    }).toList();
  }

  /// Get detailed release information by Discogs release ID.
  Future<Album?> getReleaseDetails(int discogsId) async {
    final response = await _client.get(
      '${AppConstants.discogsBaseUrl}/releases/$discogsId',
    );

    if (response == null) return null;
    final release = response as Map<String, dynamic>;

    return _parseReleaseToAlbum(release);
  }

  /// Parse a Discogs release response into an [Album].
  Album _parseReleaseToAlbum(Map<String, dynamic> release) {
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

    final labels = release['labels'] as List<dynamic>? ?? [];
    final label = labels.isNotEmpty
        ? labels.map((l) => l['name'] ?? '').join(', ')
        : null;

    return Album(
      id: 'discogs_${release['id'] ?? DateTime.now().millisecondsSinceEpoch}',
      title: release['title'] ?? 'Unknown',
      artist: artistName,
      releaseYear: year,
      label: label,
      genre: genre.isNotEmpty ? genre : null,
      tracklist: tracklist,
      coverArtUrl: release['images']?.isNotEmpty == true
          ? release['images'][0]['uri']
          : null,
      country: release['country'],
      dateAdded: DateTime.now(),
      discogsId: release['id']?.toString(),
      recognitionConfidence: 0.0,
    );
  }

  /// Extract artist name from a Discogs search result.
  String? _extractArtist(Map<String, dynamic> result) {
    // Search results have the title as "Artist - Title"
    final title = result['title'] as String?;
    if (title == null) return null;
    final dashIndex = title.indexOf(' - ');
    if (dashIndex > 0) {
      return title.substring(0, dashIndex);
    }
    return null;
  }
}
