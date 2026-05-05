import 'package:logger/logger.dart';
import '../../data/services/api/musicbrainz_service.dart';
import '../../data/services/api/discogs_service.dart';
import '../../data/services/storage/local_storage_service.dart';
import '../../data/models/album_model.dart';
import '../../data/services/ml/model/model_download_manager.dart';
import '../../data/services/ml/model/model_info.dart';

/// Represents a pending sync action.
class SyncAction {
  final String type; // 'enrich', 'update_cover', 'verify'
  final Album album;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  const SyncAction({
    required this.type,
    required this.album,
    this.data,
    required this.createdAt,
  });
}

/// Tracks sync state.
enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
}

/// Handles offline-to-online sync when connectivity returns.
///
/// When an album is recognized offline:
/// 1. Basic info is saved locally
/// 2. A sync action is queued
/// 3. When online, the action is processed:
///    - Fetch full metadata from MusicBrainz/Discogs
///    - Download cover art from Cover Art Archive
///    - Update the local record
class OfflineSyncService {
  final MusicBrainzService _musicBrainz;
  final DiscogsService _discogs;
  final LocalStorageService _storage;
  final ModelDownloadManager _modelManager;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  static const String _syncQueueKey = 'offline_sync_queue';

  SyncStatus _status = SyncStatus.idle;
  int _totalActions = 0;
  int _processedActions = 0;

  // Callbacks
  final void Function(SyncStatus status, int processed, int total)? onProgress;

  SyncStatus get status => _status;
  int get pendingCount => _totalActions - _processedActions;

  OfflineSyncService({
    required MusicBrainzService musicBrainz,
    required DiscogsService discogs,
    required LocalStorageService storage,
    required ModelDownloadManager modelManager,
    this.onProgress,
  })  : _musicBrainz = musicBrainz,
        _discogs = discogs,
        _storage = storage,
        _modelManager = modelManager;

  // ==========================================
  // Queue Management
  // ==========================================

  /// Queue an album for later online enrichment.
  Future<void> queueForSync(Album album) async {
    final action = SyncAction(
      type: 'enrich',
      album: album,
      createdAt: DateTime.now(),
    );

    final queue = await _getQueue();
    queue.add(action);
    await _saveQueue(queue);
    _totalActions = queue.length;

    _logger.i('Queued album for sync: ${album.artist} - ${album.title}');
  }

  /// Get count of pending sync actions.
  Future<int> getPendingCount() async {
    final queue = await _getQueue();
    return queue.length;
  }

  // ==========================================
  // Sync Execution
  // ==========================================

  /// Process all pending sync actions.
  Future<SyncResult> syncAll() async {
    if (_status == SyncStatus.syncing) {
      return SyncResult(alreadyRunning: true);
    }

    final queue = await _getQueue();
    if (queue.isEmpty) {
      return SyncResult(processed: 0, failed: 0);
    }

    _status = SyncStatus.syncing;
    _totalActions = queue.length;
    _processedActions = 0;
    onProgress?.call(SyncStatus.syncing, 0, _totalActions);

    int processed = 0;
    int failed = 0;
    final remaining = <SyncAction>[];

    for (final action in queue) {
      try {
        final success = await _processAction(action);
        if (success) {
          processed++;
        } else {
          failed++;
          remaining.add(action); // Keep for retry
        }
      } catch (e) {
        _logger.e('Sync action failed: $e');
        failed++;
        remaining.add(action);
      }

      _processedActions++;
      onProgress?.call(
        SyncStatus.syncing,
        _processedActions,
        _totalActions,
      );

      // Rate limiting: 1 request per second for MusicBrainz
      await Future.delayed(const Duration(seconds: 1));
    }

    // Save remaining actions
    await _saveQueue(remaining);
    _status = remaining.isEmpty ? SyncStatus.completed : SyncStatus.failed;

    _logger.i('Sync completed: $processed processed, $failed failed, '
        '${remaining.length} remaining');

    return SyncResult(
      processed: processed,
      failed: failed,
      remaining: remaining.length,
    );
  }

  /// Process a single sync action.
  Future<bool> _processAction(SyncAction action) async {
    final album = action.album;

    try {
      // Step 1: Try MusicBrainz enrichment
      Map<String, dynamic>? mbData;
      if (album.musicBrainzId != null) {
        mbData = await _musicBrainz.getReleaseDetails(album.musicBrainzId!);
      }

      // Step 2: If no MBID, search by artist+title
      mbData ??= await _musicBrainz.searchByArtistAndAlbum(
        album.artist,
        album.title,
      );

      // Step 3: Try Discogs if MusicBrainz didn't help
      Map<String, dynamic>? discogsData;
      if (mbData == null) {
        discogsData = await _discogs.searchRelease(
          '${album.artist} ${album.title}',
        );
      }

      // Step 4: Update album with enriched data
      final enriched = _enrichAlbum(album, mbData, discogsData);
      await _storage.saveAlbum(enriched);

      _logger.i('Enriched: ${album.artist} - ${album.title}');
      return true;
    } catch (e) {
      _logger.e('Failed to enrich ${album.title}: $e');
      return false;
    }
  }

  /// Enrich album with online data.
  Album _enrichAlbum(
    Album original,
    Map<String, dynamic>? mbData,
    Map<String, dynamic>? discogsData,
  ) {
    final data = mbData ?? discogsData;
    if (data == null) return original;

    return Album(
      id: original.id,
      title: data['title'] as String? ?? original.title,
      artist: data['artist'] as String? ?? original.artist,
      releaseYear: data['releaseYear'] as int? ?? original.releaseYear,
      label: data['label'] as String? ?? original.label,
      genre: data['genre'] as String? ?? original.genre,
      country: data['country'] as String? ?? original.country,
      tracklist: (data['tracklist'] as List<dynamic>?)
              ?.cast<String>()
              .isNotEmpty == true
          ? (data['tracklist'] as List<dynamic>).cast<String>()
          : original.tracklist,
      barcode: data['barcode'] as String? ?? original.barcode,
      musicBrainzId: data['musicBrainzId'] as String? ?? original.musicBrainzId,
      coverUrl: data['coverUrl'] as String? ?? original.coverUrl,
      userPhotoPath: original.userPhotoPath,
      confidence: original.confidence,
      source: '${original.source} -> enriched',
      addedAt: original.addedAt,
    );
  }

  // ==========================================
  // Persistence
  // ==========================================

  Future<List<SyncAction>> _getQueue() async {
    // Using SharedPreferences for queue persistence
    // In production, use a dedicated Hive box
    return []; // TODO: Implement with Hive box
  }

  Future<void> _saveQueue(List<SyncAction> queue) async {
    // TODO: Implement with Hive box
  }
}

/// Result of a sync operation.
class SyncResult {
  final int processed;
  final int failed;
  final int remaining;
  final bool alreadyRunning;

  const SyncResult({
    this.processed = 0,
    this.failed = 0,
    this.remaining = 0,
    this.alreadyRunning = false,
  });

  bool get isSuccess => failed == 0 && !alreadyRunning;
  bool get hasFailures => failed > 0;
}
