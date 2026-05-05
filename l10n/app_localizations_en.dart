// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Album Scanner';

  @override
  String get tabCollection => 'Collection';

  @override
  String get tabScan => 'Scan';

  @override
  String get tabSettings => 'Settings';

  @override
  String get tabWishlist => 'Wishlist';

  @override
  String get scanTitle => 'Scan Album';

  @override
  String get scanInstructions =>
      'Point the camera at an album cover or barcode';

  @override
  String get scanButton => 'Scan';

  @override
  String get scanGalleryButton => 'Pick from Gallery';

  @override
  String get scanManualButton => 'Search Manually';

  @override
  String get scanProcessing => 'Analyzing...';

  @override
  String get scanStageBarcode => 'Scanning barcode...';

  @override
  String get scanStageOcr => 'Reading text...';

  @override
  String get scanStageLabeling => 'Analyzing cover...';

  @override
  String get scanStageSearch => 'Searching databases...';

  @override
  String get scanStageOffline => 'Offline matching...';

  @override
  String get resultTitle => 'Scan Result';

  @override
  String resultConfidence(double percentage) {
    final intl.NumberFormat percentageNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentageString = percentageNumberFormat.format(percentage);

    return 'Confidence: $percentageString%';
  }

  @override
  String get resultAddToCollection => 'Add to Collection';

  @override
  String get resultAlternatives => 'Other matches';

  @override
  String get resultNoMatch => 'No album found';

  @override
  String get resultNoMatchHint =>
      'Try a clearer photo, different angle, or search manually.';

  @override
  String get collectionTitle => 'My Collection';

  @override
  String get collectionEmpty => 'No albums yet';

  @override
  String get collectionEmptySubtitle =>
      'Scan your first album to start building your collection';

  @override
  String get collectionSearch => 'Search collection...';

  @override
  String collectionAlbumCount(int count) {
    return '$count albums';
  }

  @override
  String get albumTracklist => 'Tracklist';

  @override
  String get albumGenre => 'Genre';

  @override
  String get albumLabel => 'Label';

  @override
  String get albumYear => 'Year';

  @override
  String get albumBarcode => 'Barcode';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsRecognition => 'Recognition';

  @override
  String get settingsOnlineRecognition => 'Online Recognition';

  @override
  String get settingsOcr => 'OCR Text Extraction';

  @override
  String get settingsBarcode => 'Barcode Scanning';

  @override
  String get settingsVisual => 'Visual Analysis';

  @override
  String get settingsOffline => 'Offline Mode';

  @override
  String get settingsManageModels => 'Manage Models';

  @override
  String get settingsHaptic => 'Haptic Feedback';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsShareExport => 'Share & Export';

  @override
  String get settingsImport => 'Import Collection';

  @override
  String get settingsClear => 'Clear Collection';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get errorNoConnection =>
      'No internet connection. Check your network settings.';

  @override
  String get errorTimeout => 'Server is not responding. Try again in a moment.';

  @override
  String get errorRateLimited =>
      'Too many requests. Wait a moment and try again.';

  @override
  String get errorNoResults =>
      'No album found. Try a photo from a different angle.';

  @override
  String get errorLowConfidence =>
      'Recognition uncertain. Try a clearer photo.';

  @override
  String get errorCamera => 'Camera permission is required to scan albums.';

  @override
  String get errorGeneric => 'An unexpected error occurred. Please try again.';

  @override
  String get exportJson => 'JSON';

  @override
  String get exportCsv => 'CSV';

  @override
  String get exportPdf => 'PDF';

  @override
  String get importDiscogs => 'Discogs CSV';

  @override
  String get importMusicbrainz => 'MusicBrainz JSON';

  @override
  String get importGeneric => 'Album Scanner JSON';

  @override
  String get importComplete => 'Import Complete';

  @override
  String get imported => 'Imported';

  @override
  String get duplicates => 'Duplicates';

  @override
  String get skipped => 'Skipped';

  @override
  String get onboardingPage1Title => 'Scan Your Vinyl';

  @override
  String get onboardingPage1Subtitle =>
      'Point your camera at any album cover, barcode, or label';

  @override
  String get onboardingPage2Title => 'Instant Recognition';

  @override
  String get onboardingPage3Title => 'Build Your Collection';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get statsTitle => 'Collection Stats';

  @override
  String get statsTotalAlbums => 'Total Albums';

  @override
  String get statsTotalArtists => 'Total Artists';

  @override
  String get statsTotalGenres => 'Total Genres';

  @override
  String get statsAvgConfidence => 'Avg Confidence';

  @override
  String get statsFavorites => 'Favorites';

  @override
  String get wishlistTitle => 'Wishlist';

  @override
  String get wishlistEmpty => 'Wishlist is empty';

  @override
  String get wishlistAddManual => 'Add Album';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get share => 'Share';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get loading => 'Loading...';
}
