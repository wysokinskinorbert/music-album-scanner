import 'dart:io';
import 'package:csv/csv.dart';
import 'package:dart:convert';
import 'package:file_picker/file_picker.dart';
import '../../models/album.dart';
import '../../repositories/album_repository.dart';

/// Import format types.
enum ImportFormat { discogsCsv, musicBrainzJson, genericJson }

/// Result of an import operation.
class ImportResult {
  final int imported;
  final int skipped;
  final int duplicates;
  final List<String> errors;
  final Duration duration;

  const ImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.duplicates = 0,
    this.errors = const [],
    required this.duration,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get total => imported + skipped + duplicates;
}

/// Service for importing album collections from external sources.
class ImportService {
  final AlbumRepository _repository;

  ImportService(this._repository);

  /// Pick and import a file.
  Future<ImportResult> importFromFile(ImportFormat format) async {
    final stopwatch = Stopwatch()..start();

    // Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _getAllowedExtensions(format),
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult(
        errors: ['No file selected'],
        duration: stopwatch.elapsed,
      );
    }

    final file = File(result.files.single.path!);
    if (!await file.exists()) {
      return ImportResult(
        errors: ['File not found'],
        duration: stopwatch.elapsed,
      );
    }

    final content = await file.readAsString();
    return _processContent(content, format, stopwatch);
  }

  /// Import from a specific file path.
  Future<ImportResult> importFromPath(String path, ImportFormat format) async {
    final stopwatch = Stopwatch()..start();
    final file = File(path);

    if (!await file.exists()) {
      return ImportResult(
        errors: ['File not found: \$path'],
        duration: stopwatch.elapsed,
      );
    }

    final content = await file.readAsString();
    return _processContent(content, format, stopwatch);
  }

  Future<ImportResult> _processContent(
    String content,
    ImportFormat format,
    Stopwatch stopwatch,
  ) async {
    try {
      switch (format) {
        case ImportFormat.discogsCsv:
          return _parseDiscogsCsv(content, stopwatch);
        case ImportFormat.musicBrainzJson:
          return _parseMusicBrainzJson(content, stopwatch);
        case ImportFormat.genericJson:
          return _parseGenericJson(content, stopwatch);
      }
    } catch (e) {
      return ImportResult(
        errors: ['Parse error: \$e'],
        duration: stopwatch.elapsed,
      );
    }
  }

  // ==========================================
  // Discogs CSV Parser
  // ==========================================

  /// Discogs CSV columns (standard export format):
  /// Catalog#,Artist,Title,Label,Year,Format,Collection,etc.
  Future<ImportResult> _parseDiscogsCsv(String content, Stopwatch stopwatch) async {
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) {
      return ImportResult(errors: ['Empty CSV'], duration: stopwatch.elapsed);
    }

    // Find column indices from header
    final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    final artistIdx = _findColumn(header, ['artist', 'artist_name']);
    final titleIdx = _findColumn(header, ['title', 'release_title', 'album']);
    final yearIdx = _findColumn(header, ['year', 'released']);
    final genreIdx = _findColumn(header, ['genre', 'genres']);
    final labelIdx = _findColumn(header, ['label', 'record_label']);
    final barcodeIdx = _findColumn(header, ['barcode', 'upc', 'ean']);
    final tracklistIdx = _findColumn(header, ['tracklist', 'tracks']);

    if (artistIdx == -1 || titleIdx == -1) {
      return ImportResult(
        errors: ['Required columns not found: Artist, Title'],
        duration: stopwatch.elapsed,
      );
    }

    int imported = 0;
    int skipped = 0;
    int duplicates = 0;
    final errors = <String>[];

    final existing = await _repository.getAllAlbums();
    final existingIds = existing.map((a) => '\${a.artist}|\\${a.title}'.toLowerCase()).toSet();

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      try {
        final artist = _getCellValue(row, artistIdx);
        final title = _getCellValue(row, titleIdx);
        if (artist.isEmpty || title.isEmpty) {
          skipped++;
          continue;
        }

        // Duplicate check
        final key = '\$artist|\$title'.toLowerCase();
        if (existingIds.contains(key)) {
          duplicates++;
          continue;
        }

        final album = Album(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_\$i',
          title: title,
          artist: artist,
          year: _parseIntOrNull(_getCellValue(row, yearIdx)),
          genre: _getCellValue(row, genreIdx),
          label: _getCellValue(row, labelIdx),
          barcode: _getCellValue(row, barcodeIdx),
          tracklist: _parseTracklist(_getCellValue(row, tracklistIdx)),
          dateAdded: DateTime.now(),
          confidence: 1.0,
          scanMethod: 'import_discogs',
        );

        await _repository.addAlbum(album);
        existingIds.add(key);
        imported++;
      } catch (e) {
        errors.add('Row \${i + 1}: \$e');
      }
    }

    stopwatch.stop();
    return ImportResult(
      imported: imported,
      skipped: skipped,
      duplicates: duplicates,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  // ==========================================
  // MusicBrainz JSON Parser
  // ==========================================

  /// Expects format: { "releases": [ { "title": "...", "artist-credit": [...], ... } ] }
  Future<ImportResult> _parseMusicBrainzJson(String content, Stopwatch stopwatch) async {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final releases = json['releases'] as List<dynamic>? ?? [];

    int imported = 0;
    int skipped = 0;
    int duplicates = 0;
    final errors = <String>[];

    final existing = await _repository.getAllAlbums();
    final existingIds = existing.map((a) => '\${a.artist}|\\${a.title}'.toLowerCase()).toSet();

    for (int i = 0; i < releases.length; i++) {
      try {
        final release = releases[i] as Map<String, dynamic>;
        final title = (release['title'] ?? '').toString();
        if (title.isEmpty) { skipped++; continue; }

        // Extract artist from artist-credit
        final artistCredit = release['artist-credit'] as List<dynamic>? ?? [];
        final artist = artistCredit.isNotEmpty
            ? (artistCredit[0] as Map<String, dynamic>)['name']?.toString() ?? 'Unknown'
            : 'Unknown';

        final key = '\$artist|\$title'.toLowerCase();
        if (existingIds.contains(key)) { duplicates++; continue; }

        // Extract year from date
        final dateStr = (release['date'] ?? '').toString();
        final year = int.tryParse(dateStr.substring(0, dateStr.length >= 4 ? 4 : dateStr.length));

        // Extract media/tracklist
        final media = release['media'] as List<dynamic>? ?? [];
        final tracks = <String>[];
        for (final medium in media) {
          final trackList = (medium as Map<String, dynamic>)['tracks'] as List<dynamic>? ?? [];
          for (final track in trackList) {
            tracks.add((track as Map<String, dynamic>)['title']?.toString() ?? '');
          }
        }

        final album = Album(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_mb_\$i',
          title: title,
          artist: artist,
          year: year,
          genre: null, // MB doesn't include genre in release data
          label: null, // Would need separate lookup
          musicBrainzId: release['id']?.toString(),
          tracklist: tracks,
          dateAdded: DateTime.now(),
          confidence: 1.0,
          scanMethod: 'import_musicbrainz',
        );

        await _repository.addAlbum(album);
        existingIds.add(key);
        imported++;
      } catch (e) {
        errors.add('Release \${i + 1}: \$e');
      }
    }

    stopwatch.stop();
    return ImportResult(
      imported: imported,
      skipped: skipped,
      duplicates: duplicates,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  // ==========================================
  // Generic JSON Parser (our own export format)
  // ==========================================

  Future<ImportResult> _parseGenericJson(String content, Stopwatch stopwatch) async {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final albums = json['albums'] as List<dynamic>? ?? [];

    int imported = 0;
    int skipped = 0;
    int duplicates = 0;
    final errors = <String>[];

    final existing = await _repository.getAllAlbums();
    final existingIds = existing.map((a) => '\${a.artist}|\\${a.title}'.toLowerCase()).toSet();

    for (int i = 0; i < albums.length; i++) {
      try {
        final data = albums[i] as Map<String, dynamic>;
        final title = (data['title'] ?? '').toString();
        final artist = (data['artist'] ?? '').toString();
        if (title.isEmpty || artist.isEmpty) { skipped++; continue; }

        final key = '\$artist|\$title'.toLowerCase();
        if (existingIds.contains(key)) { duplicates++; continue; }

        final tracklist = (data['tracklist'] as List<dynamic>? ?? []).cast<String>();

        final album = Album(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_gen_\$i',
          title: title,
          artist: artist,
          year: data['year'] as int?,
          genre: data['genre']?.toString(),
          label: data['label']?.toString(),
          barcode: data['barcode']?.toString(),
          musicBrainzId: data['musicBrainzId']?.toString(),
          tracklist: tracklist,
          dateAdded: DateTime.now(),
          confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
          scanMethod: 'import_json',
        );

        await _repository.addAlbum(album);
        existingIds.add(key);
        imported++;
      } catch (e) {
        errors.add('Album \${i + 1}: \$e');
      }
    }

    stopwatch.stop();
    return ImportResult(
      imported: imported,
      skipped: skipped,
      duplicates: duplicates,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  // ==========================================
  // Helpers
  // ==========================================

  int _findColumn(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = header.indexOf(candidate);
      if (idx != -1) return idx;
    }
    return -1;
  }

  String _getCellValue(List<dynamic> row, int index) {
    if (index == -1 || index >= row.length) return '';
    return row[index]?.toString() ?? '';
  }

  int? _parseIntOrNull(String value) {
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  List<String> _parseTracklist(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> _getAllowedExtensions(ImportFormat format) {
    switch (format) {
      case ImportFormat.discogsCsv:
        return ['csv'];
      case ImportFormat.musicBrainzJson:
      case ImportFormat.genericJson:
        return ['json'];
    }
  }
}
