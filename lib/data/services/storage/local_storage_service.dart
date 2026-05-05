import 'package:hive/hive.dart';
import '../../models/album_model.dart';
import '../../models/album_model.g.dart';

/// Local storage service using Hive for offline-first persistence.
class LocalStorageService {
  static const String _boxName = 'albums';
  Box<Album>? _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      // Adapter registered in main.dart;
    }
    _box = await Hive.openBox<Album>(_boxName);
  }

  Box<Album> get box {
    if (_box == null) throw StateError('LocalStorageService not initialized. Call init() first.');
    return _box!;
  }

  List<Album> getAlbums() {
    return box.values.toList();
  }

  Album? getAlbumById(String id) {
    try {
      return box.values.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAlbum(Album album) async {
    await box.put(album.id, album);
  }

  Future<void> deleteAlbum(String id) async {
    await box.delete(id);
  }

  Future<void> deleteAll() async {
    await box.clear();
  }

  Future<void> close() async {
    await _box?.close();
  }
}
