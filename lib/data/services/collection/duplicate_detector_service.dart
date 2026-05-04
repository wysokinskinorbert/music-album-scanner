import '../../data/models/album.dart';

/// A pair of potentially duplicate albums.
class DuplicatePair {
  final Album album1;
  final Album album2;
  final DuplicateType type;
  final double similarity; // 0.0 - 1.0

  const DuplicatePair({
    required this.album1,
    required this.album2,
    required this.type,
    required this.similarity,
  });

  String get reason => switch (type) {
        DuplicateType.exactMatch => 'Exact match',
        DuplicateType.barcodeMatch => 'Same barcode',
        DuplicateType.fuzzyTitle => 'Similar title',
        DuplicateType.musicBrainzId => 'Same MusicBrainz ID',
      };

  String get similarityLabel => '${(similarity * 100).toStringAsFixed(0)}%';
}

enum DuplicateType {
  exactMatch,
  barcodeMatch,
  fuzzyTitle,
  musicBrainzId,
}

/// Result of duplicate scan.
class DuplicateScanResult {
  final List<DuplicatePair> duplicates;
  final int albumsScanned;
  final Duration scanDuration;

  const DuplicateScanResult({
    required this.duplicates,
    required this.albumsScanned,
    required this.scanDuration,
  });

  int get totalDuplicates => duplicates.length;
  int get uniqueDuplicateAlbums {
    final ids = <String>{};
    for (final d in duplicates) {
      ids.add(d.album1.id ?? '');
      ids.add(d.album2.id ?? '');
    }
    return ids.length;
  }
}

/// Service for detecting duplicate albums in a collection.
class DuplicateDetectorService {
  /// Scan for duplicates.
  DuplicateScanResult detectDuplicates(List<Album> albums) {
    final stopwatch = Stopwatch()..start();
    final duplicates = <DuplicatePair>[];
    final seen = <String>{};

    for (int i = 0; i < albums.length; i++) {
      for (int j = i + 1; j < albums.length; j++) {
        final a = albums[i];
        final b = albums[j];

        // Check MusicBrainz ID match
        final mbidA = a.musicBrainzId;
        final mbidB = b.musicBrainzId;
        if (mbidA != null && mbidB != null && mbidA == mbidB) {
          final pairKey = '${a.id}_${b.id}';
          if (!seen.contains(pairKey)) {
            duplicates.add(DuplicatePair(
              album1: a,
              album2: b,
              type: DuplicateType.musicBrainzId,
              similarity: 1.0,
            ));
            seen.add(pairKey);
          }
          continue;
        }

        // Check barcode match
        final barcodeA = a.barcode;
        final barcodeB = b.barcode;
        if (barcodeA != null && barcodeB != null &&
            barcodeA.isNotEmpty && barcodeB.isNotEmpty &&
            barcodeA == barcodeB) {
          final pairKey = '${a.id}_${b.id}';
          if (!seen.contains(pairKey)) {
            duplicates.add(DuplicatePair(
              album1: a,
              album2: b,
              type: DuplicateType.barcodeMatch,
              similarity: 1.0,
            ));
            seen.add(pairKey);
          }
          continue;
        }

        // Check exact title + artist match
        final titleA = (a.title ?? '').toLowerCase().trim();
        final titleB = (b.title ?? '').toLowerCase().trim();
        final artistA = (a.artist ?? '').toLowerCase().trim();
        final artistB = (b.artist ?? '').toLowerCase().trim();

        if (titleA.isNotEmpty && titleB.isNotEmpty &&
            artistA.isNotEmpty && artistB.isNotEmpty &&
            titleA == titleB && artistA == artistB) {
          final pairKey = '${a.id}_${b.id}';
          if (!seen.contains(pairKey)) {
            duplicates.add(DuplicatePair(
              album1: a,
              album2: b,
              type: DuplicateType.exactMatch,
              similarity: 1.0,
            ));
            seen.add(pairKey);
          }
          continue;
        }

        // Fuzzy title + artist match
        if (titleA.isNotEmpty && titleB.isNotEmpty &&
            artistA.isNotEmpty && artistB.isNotEmpty) {
          final titleSim = _jaccardSimilarity(titleA, titleB);
          final artistSim = _jaccardSimilarity(artistA, artistB);
          final overall = (titleSim + artistSim) / 2;

          if (overall >= 0.75) {
            final pairKey = '${a.id}_${b.id}';
            if (!seen.contains(pairKey)) {
              duplicates.add(DuplicatePair(
                album1: a,
                album2: b,
                type: DuplicateType.fuzzyTitle,
                similarity: overall,
              ));
              seen.add(pairKey);
            }
          }
        }
      }
    }

    stopwatch.stop();

    // Sort by similarity descending
    duplicates.sort((a, b) => b.similarity.compareTo(a.similarity));

    return DuplicateScanResult(
      duplicates: duplicates,
      albumsScanned: albums.length,
      scanDuration: stopwatch.elapsed,
    );
  }

  /// Jaccard similarity on bigrams.
  double _jaccardSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final bigramsA = _bigrams(a);
    final bigramsB = _bigrams(b);

    if (bigramsA.isEmpty || bigramsB.isEmpty) return 0.0;

    final intersection = bigramsA.intersection(bigramsA.length < bigramsB.length
        ? bigramsB
        : bigramsB.where((b) => bigramsA.contains(b)).toSet());

    final intersectionSize = bigramsA.where(bigramsB.contains).length;
    final unionSize = bigramsA.length + bigramsB.length - intersectionSize;

    if (unionSize == 0) return 0.0;
    return intersectionSize / unionSize;
  }

  Set<String> _bigrams(String s) {
    final normalized = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length < 2) return {normalized};
    return {
      for (int i = 0; i < normalized.length - 1; i++)
        normalized.substring(i, i + 2)
    };
  }
}
