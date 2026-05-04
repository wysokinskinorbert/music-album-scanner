import 'package:hive/hive.dart';
import '../../models/album_model.dart';
import 'package:logger/logger.dart';

/// Wishlist entry - an album the user wants to find.
class WishlistItem {
  final String? id;
  final String? title;
  final String? artist;
  final int? year;
  final String? genre;
  final String? notes;
  final String? coverUrl;
  final DateTime dateAdded;
  final bool isFound;

  const WishlistItem({
    this.id,
    this.title,
    this.artist,
    this.year,
    this.genre,
    this.notes,
    this.coverUrl,
    required this.dateAdded,
    this.isFound = false,
  });

  WishlistItem copyWith({
    String? id,
    String? title,
    String? artist,
    int? year,
    String? genre,
    String? notes,
    String? coverUrl,
    DateTime? dateAdded,
    bool? isFound,
  }) =>
      WishlistItem(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        year: year ?? this.year,
        genre: genre ?? this.genre,
        notes: notes ?? this.notes,
        coverUrl: coverUrl ?? this.coverUrl,
        dateAdded: dateAdded ?? this.dateAdded,
        isFound: isFound ?? this.isFound,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'year': year,
        'genre': genre,
        'notes': notes,
        'coverUrl': coverUrl,
        'dateAdded': dateAdded.toIso8601String(),
        'isFound': isFound,
      };

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
        id: json['id'],
        title: json['title'],
        artist: json['artist'],
        year: json['year'],
        genre: json['genre'],
        notes: json['notes'],
        coverUrl: json['coverUrl'],
        dateAdded: DateTime.parse(json['dateAdded']),
        isFound: json['isFound'] ?? false,
      );
}

/// Service for managing album wishlist.
class WishlistService {
  static const _boxName = 'wishlist';
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<Box> _openBox() => Hive.openBox(_boxName);

  /// Get all wishlist items.
  Future<List<WishlistItem>> getAll() async {
    final box = await _openBox();
    final items = <WishlistItem>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map) {
        items.add(WishlistItem.fromJson(Map<String, dynamic>.from(data)));
      }
    }
    box.close();
    // Sort by date added (newest first)
    items.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return items;
  }

  /// Get only unfound items.
  Future<List<WishlistItem>> getUnfound() async {
    final all = await getAll();
    return all.where((item) => !item.isFound).toList();
  }

  /// Add item to wishlist.
  Future<WishlistItem> add(WishlistItem item) async {
    final box = await _openBox();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newItem = item.copyWith(id: id, dateAdded: DateTime.now());
    await box.put(id, newItem.toJson());
    box.close();
    _logger.i('Added to wishlist: ${newItem.title}');
    return newItem;
  }

  /// Add album from scan result to wishlist.
  Future<WishlistItem> addFromAlbum(Album album, {String? notes}) async {
    return add(WishlistItem(
      title: album.title,
      artist: album.artist,
      year: album.year,
      genre: album.genre,
      coverUrl: album.coverUrl,
      notes: notes,
      dateAdded: DateTime.now(),
    ));
  }

  /// Create from manual input.
  Future<WishlistItem> createManual({
    String? title,
    String? artist,
    int? year,
    String? genre,
    String? notes,
  }) async {
    return add(WishlistItem(
      title: title,
      artist: artist,
      year: year,
      genre: genre,
      notes: notes,
      dateAdded: DateTime.now(),
    ));
  }

  /// Mark item as found.
  Future<void> markFound(String id) async {
    final box = await _openBox();
    final data = box.get(id);
    if (data != null) {
      final item = WishlistItem.fromJson(Map<String, dynamic>.from(data));
      final updated = item.copyWith(isFound: true);
      await box.put(id, updated.toJson());
      _logger.i('Marked as found: ${item.title}');
    }
    box.close();
  }

  /// Remove item from wishlist.
  Future<void> remove(String id) async {
    final box = await _openBox();
    await box.delete(id);
    box.close();
    _logger.i('Removed from wishlist: $id');
  }

  /// Update item notes.
  Future<void> updateNotes(String id, String notes) async {
    final box = await _openBox();
    final data = box.get(id);
    if (data != null) {
      final item = WishlistItem.fromJson(Map<String, dynamic>.from(data));
      await box.put(id, item.copyWith(notes: notes).toJson());
    }
    box.close();
  }

  /// Get wishlist count.
  Future<int> count() async {
    final items = await getAll();
    return items.length;
  }

  /// Get unfound count.
  Future<int> unfoundCount() async {
    final items = await getUnfound();
    return items.length;
  }

  /// Search wishlist.
  Future<List<WishlistItem>> search(String query) async {
    final all = await getAll();
    final q = query.toLowerCase();
    return all.where((item) {
      return (item.title?.toLowerCase().contains(q) ?? false) ||
          (item.artist?.toLowerCase().contains(q) ?? false) ||
          (item.notes?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Check if an album is already on the wishlist (by title + artist).
  Future<bool> isOnWishlist(String title, String artist) async {
    final all = await getAll();
    return all.any((item) =>
        item.title?.toLowerCase() == title.toLowerCase() &&
        item.artist?.toLowerCase() == artist.toLowerCase());
  }
}
