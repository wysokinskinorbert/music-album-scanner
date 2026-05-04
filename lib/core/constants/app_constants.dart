/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Album Scanner';
  static const String appVersion = '0.1.0';

  // API endpoints
  static const String musicBrainzBaseUrl = 'https://musicbrainz.org/ws/2';
  static const String coverArtArchiveUrl = 'https://coverartarchive.org';
  static const String discogsBaseUrl = 'https://api.discogs.com';

  // Rate limits
  static const Duration musicBrainzRateLimit = Duration(seconds: 1);
  static const int discogsRequestsPerMinute = 60;

  // Storage
  static const String hiveBoxName = 'album_scanner';
  static const String collectionBoxName = 'collection';
  static const String settingsBoxName = 'settings';

  // ML Model
  static const String offlineModelName = 'album_cover_mobilenet.tflite';
  static const double confidenceThreshold = 0.7;
  static const int maxRecognitionResults = 5;

  // Camera
  static const double maxImageWidth = 1920;
  static const double maxImageHeight = 1920;
  static const int imageQuality = 90;

  // UI
  static const double borderRadius = 16.0;
  static const double cardPadding = 16.0;
  static const double bottomNavHeight = 72.0;
}
