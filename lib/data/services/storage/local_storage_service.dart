import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/album_model.dart';

/// Local persistence layer using Hive for offline-first storage.
class LocalStorageService {
  late Box<Album> _collectionBox;
  late Box _settingsBox;
  final _uuid = const Uuid();

  /// Initialize Hive and open boxes.
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    Hive.registerAdapter(AlbumAdapter());

    _collectionBox = await Hive.openBox<Album>(
      AppConstants.collectionBoxName,
    );
    _settingsBox = await Hive.openBox(
      AppConstants.settingsBoxName,
    );
  }

  // -- Collection CRUD --

  /// Add a new album to the collection.
  Future<Album> addAlbum(Album album) async {
    await _collectionBox.put(album.id, album);
    return album;
  }

  /// Create album from recognition data.
  Future<Album> createAlbumFromRecognition({
    required String title,
    required String artist,
    int? releaseYear,
    String? label,
    String? genre,
    List<String> tracklist = const [],
    String? coverArtUrl,
    String? userPhotoPath,
    String? musicBrainzId,
    String? discogsId,
    double confidence = 0.0,
  }) async {
    final album = Album(
      id: _uuid.v4(),
      title: title,
      artist: artist,
      releaseYear: releaseYear,
      label: label,
      genre: genre,
      tracklist: tracklist,
      coverArtUrl: coverArtUrl,
      userPhotoPath: userPhotoPath,
      dateAdded: DateTime.now(),
      musicBrainzId: musicBrainzId,
      discogsId: discogsId,
      recognitionConfidence: confidence,
    );

    await _collectionBox.put(album.id, album);
    return album;
  }

  /// Get all albums in collection.
  List<Album> getAllAlbums() {
    return _collectionBox.values.toList()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
  }

  /// Get album by ID.
  Album? getAlbum(String id) => _collectionBox.get(id);

  /// Update an existing album.
  Future<void> updateAlbum(Album album) async {
    await _collectionBox.put(album.id, album);
  }

  /// Delete an album from collection.
  Future<void> deleteAlbum(String id) async {
    await _collectionBox.delete(id);
  }

  /// Search collection by title or artist.
  List<Album> searchCollection(String query) {
    final q = query.toLowerCase();
    return _collectionBox.values
        .where((album) =>
            album.title.toLowerCase().contains(q) ||
            album.artist.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
  }

  /// Get total album count.
  int get albumCount => _collectionBox.length;

  // -- Export --

  /// Export collection to JSON-compatible map.
  List<Map<String, dynamic>> exportToJson() {
    return _collectionBox.values.map((album) => {
      'id': album.id,
      'title': album.title,
      'artist': album.artist,
      'releaseYear': album.releaseYear,
      'label': album.label,
      'genre': album.genre,
      'tracklist': album.tracklist,
      'dateAdded': album.dateAdded.toIso8601String(),
    }).toList();
  }

  // -- Settings --

  T? getSetting<T>(String key) => _settingsBox.get(key) as T?;

  Future<void> setSetting<T>(String key, T value) async {
    await _settingsBox.put(key, value);
  }

  // -- Cleanup --

  /// Delete user photo file.
  Future<void> deleteUserPhoto(String? photoPath) async {
    if (photoPath != null) {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  void dispose() {
    _collectionBox.close();
    _settingsBox.close();
  }
}
