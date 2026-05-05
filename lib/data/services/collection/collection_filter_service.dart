import '../../models/album_model.dart';

/// Filter criteria for album collection.
class CollectionFilter {
  final String? searchQuery;
  final String? genre;
  final int? decade;        // e.g. 1990 for 1990s
  final String? label;
  final double? minConfidence;
  final int? yearFrom;
  final int? yearTo;
  final bool? favoritesOnly;
  final DateTime? addedAfter;
  final DateTime? addedBefore;

  const CollectionFilter({
    this.searchQuery,
    this.genre,
    this.decade,
    this.label,
    this.minConfidence,
    this.yearFrom,
    this.yearTo,
    this.favoritesOnly,
    this.addedAfter,
    this.addedBefore,
  });

  bool get isEmpty =>
      searchQuery == null &&
      genre == null &&
      decade == null &&
      label == null &&
      minConfidence == null &&
      yearFrom == null &&
      yearTo == null &&
      favoritesOnly != true &&
      addedAfter == null &&
      addedBefore == null;

  CollectionFilter copyWith({
    String? searchQuery,
    String? genre,
    int? decade,
    String? label,
    double? minConfidence,
    int? yearFrom,
    int? yearTo,
    bool? favoritesOnly,
    DateTime? addedAfter,
    DateTime? addedBefore,
    bool clearSearch = false,
    bool clearGenre = false,
    bool clearDecade = false,
    bool clearLabel = false,
    bool clearConfidence = false,
    bool clearYearRange = false,
    bool clearFavorites = false,
    bool clearDateRange = false,
  }) {
    return CollectionFilter(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      genre: clearGenre ? null : (genre ?? this.genre),
      decade: clearDecade ? null : (decade ?? this.decade),
      label: clearLabel ? null : (label ?? this.label),
      minConfidence: clearConfidence ? null : (minConfidence ?? this.minConfidence),
      yearFrom: clearYearRange ? null : (yearFrom ?? this.yearFrom),
      yearTo: clearYearRange ? null : (yearTo ?? this.yearTo),
      favoritesOnly: clearFavorites ? false : (favoritesOnly ?? this.favoritesOnly),
      addedAfter: clearDateRange ? null : (addedAfter ?? this.addedAfter),
      addedBefore: clearDateRange ? null : (addedBefore ?? this.addedBefore),
    );
  }
}

/// Service for filtering album collections.
class CollectionFilterService {
  /// Apply filters to album list.
  List<Album> filter(List<Album> albums, CollectionFilter filter) {
    if (filter.isEmpty) return albums;

    return albums.where((album) {
      // Search query - matches title, artist, label
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        final matchesTitle = (album.title ?? '').toLowerCase().contains(query);
        final matchesArtist = (album.artist ?? '').toLowerCase().contains(query);
        final matchesLabel = (album.label ?? '').toLowerCase().contains(query);
        final matchesGenre = (album.genre ?? '').toLowerCase().contains(query);
        if (!matchesTitle && !matchesArtist && !matchesLabel && !matchesGenre) {
          return false;
        }
      }

      // Genre filter
      if (filter.genre != null) {
        if ((album.genre ?? '').toLowerCase() != filter.genre!.toLowerCase()) {
          return false;
        }
      }

      // Decade filter
      if (filter.decade != null) {
        final year = album.year ?? 0;
        final albumDecade = (year ~/ 10) * 10;
        if (albumDecade != filter.decade) return false;
      }

      // Label filter
      if (filter.label != null) {
        if ((album.label ?? '').toLowerCase() != filter.label!.toLowerCase()) {
          return false;
        }
      }

      // Min confidence
      if (filter.minConfidence != null) {
        if ((album.scanConfidence ?? 0) < filter.minConfidence!) return false;
      }

      // Year range
      if (filter.yearFrom != null) {
        if ((album.year ?? 0) < filter.yearFrom!) return false;
      }
      if (filter.yearTo != null) {
        if ((album.year ?? 0) > filter.yearTo!) return false;
      }

      // Favorites
      if (filter.favoritesOnly == true) {
        if (album.isFavorite != true) return false;
      }

      // Date range
      if (filter.addedAfter != null) {
        if (album.dateAdded == null || album.dateAdded!.isBefore(filter.addedAfter!)) {
          return false;
        }
      }
      if (filter.addedBefore != null) {
        if (album.dateAdded == null || album.dateAdded!.isAfter(filter.addedBefore!)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Extract available genres from collection.
  List<String> extractGenres(List<Album> albums) {
    final genres = <String>{};
    for (final album in albums) {
      if (album.genre != null && album.genre!.isNotEmpty) {
        // Split multi-genre entries
        for (final g in album.genre!.split(RegExp(r'[,;/]'))) {
          final trimmed = g.trim();
          if (trimmed.isNotEmpty) genres.add(trimmed);
        }
      }
    }
    return genres.toList()..sort();
  }

  /// Extract available decades from collection.
  List<int> extractDecades(List<Album> albums) {
    final decades = <int>{};
    for (final album in albums) {
      if (album.year != null && album.year! > 0) {
        decades.add((album.year! ~/ 10) * 10);
      }
    }
    return decades.toList()..sort();
  }

  /// Extract available labels from collection.
  List<String> extractLabels(List<Album> albums) {
    final labels = <String>{};
    for (final album in albums) {
      if (album.label != null && album.label!.isNotEmpty) {
        labels.add(album.label!);
      }
    }
    return labels.toList()..sort();
  }
}
