import 'package:uuid/uuid.dart';
import '../models/album_model.dart';
import '../services/storage/local_storage_service.dart';

/// Repository pattern for album collection management.
class AlbumRepository {
  final LocalStorageService _storage;
  final _uuid = const Uuid();

  AlbumRepository(this._storage);

  Future<void> addAlbum(Album album) => _storage.saveAlbum(album);

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
    double recognitionConfidence = 0.0,
    String? barcode,
    String? country,
    String? format,
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
      recognitionConfidence: recognitionConfidence,
      barcode: barcode,
      country: country,
      format: format,
    );
    await _storage.saveAlbum(album);
    return album;
  }

  List<Album> getAllAlbums() => _storage.getAlbums();
  Album? getAlbum(String id) => _storage.getAlbumById(id);
  Future<void> updateAlbum(Album album) => _storage.saveAlbum(album);
  Future<void> deleteAlbum(String id) => _storage.deleteAlbum(id);

  List<Album> search(String query) {
    final q = query.toLowerCase();
    return _storage.getAlbums().where((a) =>
      a.title.toLowerCase().contains(q) ||
      a.artist.toLowerCase().contains(q) ||
      (a.genre?.toLowerCase().contains(q) ?? false) ||
      (a.label?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  int get count => _storage.getAlbums().length;

  List<Map<String, dynamic>> exportCollection() {
    return _storage.getAlbums().map((a) => {
      'id': a.id,
      'title': a.title,
      'artist': a.artist,
      'releaseYear': a.releaseYear,
      'genre': a.genre,
      'label': a.label,
      'barcode': a.barcode,
      'musicBrainzId': a.musicBrainzId,
      'discogsId': a.discogsId,
    }).toList();
  }
}
