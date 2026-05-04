import '../models/album_model.dart';
import '../services/storage/local_storage_service.dart';

/// Repository pattern for album collection management.
class AlbumRepository {
  final LocalStorageService _storage;

  AlbumRepository(this._storage);

  Future<Album> addAlbum(Album album) => _storage.addAlbum(album);

  Future<Album> createAlbum({
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
  }) {
    return _storage.createAlbumFromRecognition(
      title: title,
      artist: artist,
      releaseYear: releaseYear,
      label: label,
      genre: genre,
      tracklist: tracklist,
      coverArtUrl: coverArtUrl,
      userPhotoPath: userPhotoPath,
      musicBrainzId: musicBrainzId,
      discogsId: discogsId,
      confidence: confidence,
    );
  }

  List<Album> getAllAlbums() => _storage.getAllAlbums();
  Album? getAlbum(String id) => _storage.getAlbum(id);
  Future<void> updateAlbum(Album album) => _storage.updateAlbum(album);
  Future<void> deleteAlbum(String id) => _storage.deleteAlbum(id);
  List<Album> search(String query) => _storage.searchCollection(query);
  int get count => _storage.albumCount;

  List<Map<String, dynamic>> exportCollection() => _storage.exportToJson();
}
