import '../../data/models/album_model.dart';

/// Statistics about a user's album collection.
class CollectionStats {
  final int totalAlbums;
  final int totalArtists;
  final int totalGenres;
  final int totalLabels;
  final int favoritesCount;
  final int scannedWithBarcode;
  final int scannedWithOcr;
  final int scannedOffline;
  final double avgConfidence;
  final int? earliestYear;
  final int? latestYear;
  final Map<String, int> genreDistribution;
  final Map<String, int> decadeDistribution;
  final Map<String, int> topArtists;
  final Map<String, int> topLabels;
  final List<Album> recentAdditions;
  final double collectionValue;

  const CollectionStats({
    this.totalAlbums = 0,
    this.totalArtists = 0,
    this.totalGenres = 0,
    this.totalLabels = 0,
    this.favoritesCount = 0,
    this.scannedWithBarcode = 0,
    this.scannedWithOcr = 0,
    this.scannedOffline = 0,
    this.avgConfidence = 0,
    this.earliestYear,
    this.latestYear,
    this.genreDistribution = const {},
    this.decadeDistribution = const {},
    this.topArtists = const {},
    this.topLabels = const {},
    this.recentAdditions = const [],
    this.collectionValue = 0,
  });

  String get yearRange {
    if (earliestYear == null || latestYear == null) return 'Unknown';
    if (earliestYear == latestYear) return '$earliestYear';
    return '$earliestYear - $latestYear';
  }

  String get avgConfidenceLabel =>
      '${(avgConfidence * 100).toStringAsFixed(0)}%';

  double get barcodeScanRate =>
      totalAlbums == 0 ? 0 : scannedWithBarcode / totalAlbums;

  double get offlineScanRate =>
      totalAlbums == 0 ? 0 : scannedOffline / totalAlbums;
}

/// Service for computing collection statistics.
class CollectionStatsService {
  /// Compute full statistics from a list of albums.
  CollectionStats compute(List<Album> albums) {
    if (albums.isEmpty) return const CollectionStats();

    // Artists
    final artistCounts = <String, int>{};
    for (final a in albums) {
      final artist = a.artist;
      artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
    }
    final topArtists = _topN(artistCounts, 10);

    // Genres
    final genreCounts = <String, int>{};
    for (final a in albums) {
      if (a.genre != null && a.genre!.isNotEmpty) {
        for (final g in a.genre!.split(RegExp(r'[,;/]'))) {
          final trimmed = g.trim();
          if (trimmed.isNotEmpty) {
            genreCounts[trimmed] = (genreCounts[trimmed] ?? 0) + 1;
          }
        }
      }
    }

    // Decades
    final decadeCounts = <String, int>{};
    for (final a in albums) {
      if (a.releaseYear != null && a.releaseYear! > 0) {
        final decade = '${(a.releaseYear! ~/ 10) * 10}s';
        decadeCounts[decade] = (decadeCounts[decade] ?? 0) + 1;
      }
    }

    // Labels
    final labelCounts = <String, int>{};
    for (final a in albums) {
      if (a.label != null && a.label!.isNotEmpty) {
        labelCounts[a.label!] = (labelCounts[a.label!] ?? 0) + 1;
      }
    }
    final topLabels = _topN(labelCounts, 10);

    // Year range
    final years = albums
        .where((a) => a.releaseYear != null && a.releaseYear! > 0)
        .map((a) => a.releaseYear!)
        .toList();

    // Scan methods
    int barcode = 0, ocr = 0, offline = 0;
    double totalConfidence = 0;

    for (final a in albums) {
      totalConfidence += a.recognitionConfidence;

      // Determine scan method from barcode presence
      if (a.barcode != null && a.barcode!.isNotEmpty) {
        barcode++;
      }
    }

    // Recent additions (last 5)
    final sorted = List<Album>.from(albums)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    final recent = sorted.take(5).toList();

    return CollectionStats(
      totalAlbums: albums.length,
      totalArtists: artistCounts.length,
      totalGenres: genreCounts.length,
      totalLabels: labelCounts.length,
      favoritesCount: 0,
      scannedWithBarcode: barcode,
      scannedWithOcr: ocr,
      scannedOffline: offline,
      avgConfidence: totalConfidence / albums.length,
      earliestYear: years.isEmpty ? null : years.reduce((a, b) => a < b ? a : b),
      latestYear: years.isEmpty ? null : years.reduce((a, b) => a > b ? a : b),
      genreDistribution: genreCounts,
      decadeDistribution: decadeCounts,
      topArtists: topArtists,
      topLabels: topLabels,
      recentAdditions: recent,
    );
  }

  Map<String, int> _topN(Map<String, int> counts, int n) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted.take(n)) e.key: e.value};
  }
}
