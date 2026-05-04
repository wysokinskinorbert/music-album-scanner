import '../../models/album_model.g.dart';
     1|import 'dart:io';
     2|import 'package:hive/hive.dart';
     3|import 'package:path_provider/path_provider.dart';
     4|import 'package:uuid/uuid.dart';
     5|import '../../../core/constants/app_constants.dart';
     6|import '../../models/album_model.dart';
     7|
     8|/// Local persistence layer using Hive for offline-first storage.
     9|class LocalStorageService {
    10|  late Box<Album> _collectionBox;
    11|  late Box _settingsBox;
    12|  final _uuid = const Uuid();
    13|
    14|  /// Initialize Hive and open boxes.
    15|  Future<void> init() async {
    16|    final appDir = await getApplicationDocumentsDirectory();
    17|    Hive.init(appDir.path);
    18|    Hive.registerAdapter(AlbumAdapter());
    19|
    20|    _collectionBox = await Hive.openBox<Album>(
    21|      AppConstants.collectionBoxName,
    22|    );
    23|    _settingsBox = await Hive.openBox(
    24|      AppConstants.settingsBoxName,
    25|    );
    26|  }
    27|
    28|  // -- Collection CRUD --
    29|
    30|  /// Add a new album to the collection.
    31|  Future<Album> addAlbum(Album album) async {
    32|    await _collectionBox.put(album.id, album);
    33|    return album;
    34|  }
    35|
    36|  /// Create album from recognition data.
    37|  Future<Album> createAlbumFromRecognition({
    38|    required String title,
    39|    required String artist,
    40|    int? releaseYear,
    41|    String? label,
    42|    String? genre,
    43|    List<String> tracklist = const [],
    44|    String? coverArtUrl,
    45|    String? userPhotoPath,
    46|    String? musicBrainzId,
    47|    String? discogsId,
    48|    double confidence = 0.0,
    49|  }) async {
    50|    final album = Album(
    51|      id: _uuid.v4(),
    52|      title: title,
    53|      artist: artist,
    54|      releaseYear: releaseYear,
    55|      label: label,
    56|      genre: genre,
    57|      tracklist: tracklist,
    58|      coverArtUrl: coverArtUrl,
    59|      userPhotoPath: userPhotoPath,
    60|      dateAdded: DateTime.now(),
    61|      musicBrainzId: musicBrainzId,
    62|      discogsId: discogsId,
    63|      recognitionConfidence: confidence,
    64|    );
    65|
    66|    await _collectionBox.put(album.id, album);
    67|    return album;
    68|  }
    69|
    70|  /// Get all albums in collection.
    71|  List<Album> getAllAlbums() {
    72|    return _collectionBox.values.toList()
    73|      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    74|  }
    75|
    76|  /// Get album by ID.
    77|  Album? getAlbum(String id) => _collectionBox.get(id);
    78|
    79|  /// Update an existing album.
    80|  Future<void> updateAlbum(Album album) async {
    81|    await _collectionBox.put(album.id, album);
    82|  }
    83|
    84|  /// Delete an album from collection.
    85|  Future<void> deleteAlbum(String id) async {
    86|    await _collectionBox.delete(id);
    87|  }
    88|
    89|  /// Search collection by title or artist.
    90|  List<Album> searchCollection(String query) {
    91|    final q = query.toLowerCase();
    92|    return _collectionBox.values
    93|        .where((album) =>
    94|            album.title.toLowerCase().contains(q) ||
    95|            album.artist.toLowerCase().contains(q))
    96|        .toList()
    97|      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    98|  }
    99|
   100|  /// Get total album count.
   101|  int get albumCount => _collectionBox.length;
   102|
   103|  // -- Export --
   104|
   105|  /// Export collection to JSON-compatible map.
   106|  List<Map<String, dynamic>> exportToJson() {
   107|    return _collectionBox.values.map((album) => {
   108|      'id': album.id,
   109|      'title': album.title,
   110|      'artist': album.artist,
   111|      'releaseYear': album.releaseYear,
   112|      'label': album.label,
   113|      'genre': album.genre,
   114|      'tracklist': album.tracklist,
   115|      'dateAdded': album.dateAdded.toIso8601String(),
   116|    }).toList();
   117|  }
   118|
   119|  // -- Settings --
   120|
   121|  T? getSetting<T>(String key) => _settingsBox.get(key) as T?;
   122|
   123|  Future<void> setSetting<T>(String key, T value) async {
   124|    await _settingsBox.put(key, value);
   125|  }
   126|
   127|  // -- Cleanup --
   128|
   129|  /// Delete user photo file.
   130|  Future<void> deleteUserPhoto(String? photoPath) async {
   131|    if (photoPath != null) {
   132|      final file = File(photoPath);
   133|      if (await file.exists()) {
   134|        await file.delete();
   135|      }
   136|    }
   137|  }
   138|
   139|  void dispose() {
   140|    _collectionBox.close();
   141|    _settingsBox.close();
   142|  }
   143|}
   144|