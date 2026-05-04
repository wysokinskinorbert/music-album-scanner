import '../../data/models/album_model.dart';

/// Sort options for the album collection.
enum SortField {
  dateAdded,
  title,
  artist,
  year,
  genre,
  label,
  confidence,
}

enum SortOrder { ascending, descending }

class SortConfig {
  final SortField field;
  final SortOrder order;

  const SortConfig({
    this.field = SortField.dateAdded,
    this.order = SortOrder.descending,
  });

  SortConfig copyWith({SortField? field, SortOrder? order}) =>
      SortConfig(field: field ?? this.field, order: order ?? this.order);

  String get label => '\${field.label} (\${order.label})';
}

extension on SortField {
  String get label => switch (this) {
        SortField.dateAdded => 'Date Added',
        SortField.title => 'Title',
        SortField.artist => 'Artist',
        SortField.year => 'Year',
        SortField.genre => 'Genre',
        SortField.label => 'Label',
        SortField.confidence => 'Confidence',
      };
}

extension on SortOrder {
  String get label => switch (this) {
        SortOrder.ascending => 'A-Z',
        SortOrder.descending => 'Z-A',
      };
}

/// Service for sorting album collections.
class CollectionSortService {
  /// Sort albums by the given configuration.
  List<Album> sort(List<Album> albums, SortConfig config) {
    final sorted = List<Album>.from(albums);
    final multiplier = config.order == SortOrder.ascending ? 1 : -1;

    sorted.sort((a, b) {
      int result;
      switch (config.field) {
        case SortField.dateAdded:
          result = (a.dateAdded ?? DateTime(1970))
              .compareTo(b.dateAdded ?? DateTime(1970));
        case SortField.title:
          result = (a.title ?? '').toLowerCase().compareTo(
                (b.title ?? '').toLowerCase(),
              );
        case SortField.artist:
          result = (a.artist ?? '').toLowerCase().compareTo(
                (b.artist ?? '').toLowerCase(),
              );
        case SortField.year:
          result = (a.year ?? 0).compareTo(b.year ?? 0);
        case SortField.genre:
          result = (a.genre ?? '').toLowerCase().compareTo(
                (b.genre ?? '').toLowerCase(),
              );
        case SortField.label:
          result = (a.label ?? '').toLowerCase().compareTo(
                (b.label ?? '').toLowerCase(),
              );
        case SortField.confidence:
          result = (a.scanConfidence ?? 0.0)
              .compareTo(b.scanConfidence ?? 0.0);
      }
      return result * multiplier;
    });

    return sorted;
  }

  /// Group albums by a field for section headers.
  Map<String, List<Album>> groupBy(List<Album> albums, SortField field) {
    final groups = <String, List<Album>>{};

    for (final album in albums) {
      final key = _groupKey(album, field);
      groups.putIfAbsent(key, () => []).add(album);
    }

    // Sort keys alphabetically
    final sortedKeys = groups.keys.toList()..sort();
    return {for (final k in sortedKeys) k: groups[k]!};
  }

  String _groupKey(Album album, SortField field) => switch (field) {
        SortField.dateAdded =>
          _dateGroupKey(album.dateAdded ?? DateTime(1970)),
        SortField.title =>
          (album.title ?? '?')[0].toUpperCase(),
        SortField.artist =>
          (album.artist ?? '?')[0].toUpperCase(),
        SortField.year =>
          (album.year ?? 0) == 0 ? 'Unknown' : (album.year?.toString() ?? '?'),
        SortField.genre =>
          album.genre ?? 'Unknown',
        SortField.label =>
          album.label ?? 'Unknown',
        SortField.confidence =>
          _confidenceGroupKey(album.scanConfidence ?? 0),
      };

  String _dateGroupKey(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return 'This Week';
    if (diff.inDays < 30) return 'This Month';
    if (diff.inDays < 365) return 'This Year';
    return '\${date.year}';
  }

  String _confidenceGroupKey(double confidence) {
    if (confidence >= 0.9) return 'High (90-100%)';
    if (confidence >= 0.7) return 'Good (70-89%)';
    if (confidence >= 0.5) return 'Medium (50-69%)';
    return 'Low (<50%)';
  }
}
