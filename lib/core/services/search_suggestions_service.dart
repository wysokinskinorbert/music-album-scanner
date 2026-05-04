import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

/// Recent search query with metadata.
class SearchEntry {
  final String query;
  final DateTime timestamp;
  final int resultCount;

  const SearchEntry({
    required this.query,
    required this.timestamp,
    required this.resultCount,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'timestamp': timestamp.toIso8601String(),
        'resultCount': resultCount,
      };

  factory SearchEntry.fromJson(Map<String, dynamic> json) => SearchEntry(
        query: json['query'],
        timestamp: DateTime.parse(json['timestamp']),
        resultCount: json['resultCount'] ?? 0,
      );
}

/// Service for managing search suggestions and recent searches.
class SearchSuggestionsService {
  static const _boxName = 'search_history';
  static const _maxEntries = 50;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<Box> _openBox() => Hive.openBox(_boxName);

  /// Save a search query to history.
  Future<void> addSearch(String query, {int resultCount = 0}) async {
    if (query.trim().isEmpty) return;

    final box = await _openBox();
    final normalized = query.trim().toLowerCase();

    // Remove duplicate if exists
    final existing = box.toMap().entries.where(
      (e) => (e.value as Map?)?['query']?.toString().toLowerCase() == normalized,
    );
    for (final e in existing) {
      await box.delete(e.key);
    }

    // Add new entry
    final entry = SearchEntry(
      query: query.trim(),
      timestamp: DateTime.now(),
      resultCount: resultCount,
    );

    await box.put(entry.timestamp.millisecondsSinceEpoch.toString(), entry.toJson());

    // Trim to max entries
    if (box.length > _maxEntries) {
      final keys = box.keys.toList()..sort();
      for (int i = 0; i < keys.length - _maxEntries; i++) {
        await box.delete(keys[i]);
      }
    }

    box.close();
  }

  /// Get recent searches, newest first.
  Future<List<SearchEntry>> getRecent({int limit = 10}) async {
    final box = await _openBox();
    final entries = <SearchEntry>[];

    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map) {
        entries.add(SearchEntry.fromJson(Map<String, dynamic>.from(data)));
      }
    }
    box.close();

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.take(limit).toList();
  }

  /// Get search suggestions based on partial query.
  Future<List<String>> getSuggestions(String partialQuery, {int limit = 5}) async {
    if (partialQuery.trim().isEmpty) {
      final recent = await getRecent(limit: limit);
      return recent.map((e) => e.query).toList();
    }

    final all = await getRecent(limit: _maxEntries);
    final q = partialQuery.toLowerCase();

    final matches = all
        .where((e) => e.query.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return matches.take(limit).map((e) => e.query).toList();
  }

  /// Clear all search history.
  Future<void> clearHistory() async {
    final box = await _openBox();
    await box.clear();
    box.close();
    _logger.i('Search history cleared');
  }

  /// Delete a single search entry.
  Future<void> deleteEntry(String query) async {
    final box = await _openBox();
    final normalized = query.toLowerCase();

    final toDelete = box.toMap().entries.where(
      (e) => (e.value as Map?)?['query']?.toString().toLowerCase() == normalized,
    );

    for (final e in toDelete) {
      await box.delete(e.key);
    }
    box.close();
  }
}
