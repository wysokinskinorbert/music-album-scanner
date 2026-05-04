     1|import '../../../core/network/api_client.dart';
     2|import '../../../core/constants/app_constants.dart';
     3|
     4|/// Discogs API integration as fallback for album recognition.
     5|class DiscogsService {
     6|  final ApiClient _client;
     7|  String? _token;
     8|
     9|  DiscogsService(this._client);
    10|
    11|  void setToken(String token) => _token = token;
    12|
    13|  /// Search database by query string.
    14|  Future<List<Map<String, dynamic>>> search({
    15|    required String query,
    16|    String type = 'release',
    17|    int perPage = 5,
    18|  }) async {
    19|    final queryParams = {
    20|      'q': query,
    21|      'type': type,
    22|      'per_page': perPage,
    23|    };
    24|    if (_token != null) {
    25|      queryParams['token'] = _token;
    26|    }
    27|
    28|    final response = await _client.get(
    29|      '${AppConstants.discogsBaseUrl}/database/search',
    30|      queryParameters: queryParams,
    31|    );
    32|
    33|    final data = response.data as Map<String, dynamic>;
    34|    final results = data['results'] as List<dynamic>? ?? [];
    35|    return results.cast<Map<String, dynamic>>();
    36|  }
    37|
    38|  /// Get detailed release information.
    39|  Future<Map<String, dynamic>?> getRelease(int releaseId) async {
    40|    final response = await _client.get(
    41|      '${AppConstants.discogsBaseUrl}/releases/$releaseId',
    42|    );
    43|    return response.data as Map<String, dynamic>?;
    44|  }
    45|
    46|  /// Parse Discogs release into standardized format.
    47|  Map<String, dynamic> parseRelease(Map<String, dynamic> release) {
    48|    final tracklist = <String>[];
    49|    final rawTracklist = release['tracklist'] as List<dynamic>? ?? [];
    50|    for (final track in rawTracklist) {
    51|      tracklist.add(track['title'] as String? ?? '');
    52|    }
    53|
    54|    final artists = release['artists'] as List<dynamic>? ?? [];
    55|    final artistName = artists.isNotEmpty
    56|        ? (artists[0]['name'] ?? 'Unknown')
    57|        : 'Unknown';
    58|
    59|    final year = int.tryParse(release['year']?.toString() ?? '');
    60|
    61|    final genres = release['genres'] as List<dynamic>? ?? [];
    62|    final styles = release['styles'] as List<dynamic>? ?? [];
    63|    final genre = [...genres, ...styles].join(', ');
    64|
    65|    return {
    66|      'discogsId': release['id']?.toString(),
    67|      'title': release['title'] ?? 'Unknown',
    68|      'artist': artistName,
    69|      'releaseYear': year,
    70|      'label': (release['labels'] as List<dynamic>? ?? [])
    71|          .map((l) => l['name'] ?? '')
    72|          .join(', '),
    73|      'genre': genre.isNotEmpty ? genre : null,
    74|      'country': release['country'],
    75|      'tracklist': tracklist,
    76|      'coverArtUrl': release['images']?.isNotEmpty == true
    77|          ? release['images'][0]['uri']
    78|          : null,
    79|    };
    80|  }
    81|}
    82|