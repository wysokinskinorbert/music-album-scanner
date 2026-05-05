import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Album Scanner'**
  String get appTitle;

  /// Bottom nav tab label
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get tabCollection;

  /// Bottom nav scan tab
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get tabScan;

  /// Bottom nav settings tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Bottom nav wishlist tab
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get tabWishlist;

  /// Scan screen title
  ///
  /// In en, this message translates to:
  /// **'Scan Album'**
  String get scanTitle;

  /// Camera viewfinder instructions
  ///
  /// In en, this message translates to:
  /// **'Point the camera at an album cover or barcode'**
  String get scanInstructions;

  /// Scan action button
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanButton;

  /// Gallery picker button
  ///
  /// In en, this message translates to:
  /// **'Pick from Gallery'**
  String get scanGalleryButton;

  /// Manual search button
  ///
  /// In en, this message translates to:
  /// **'Search Manually'**
  String get scanManualButton;

  /// Processing indicator
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get scanProcessing;

  /// Pipeline stage
  ///
  /// In en, this message translates to:
  /// **'Scanning barcode...'**
  String get scanStageBarcode;

  /// Pipeline stage
  ///
  /// In en, this message translates to:
  /// **'Reading text...'**
  String get scanStageOcr;

  /// Pipeline stage
  ///
  /// In en, this message translates to:
  /// **'Analyzing cover...'**
  String get scanStageLabeling;

  /// Pipeline stage
  ///
  /// In en, this message translates to:
  /// **'Searching databases...'**
  String get scanStageSearch;

  /// Pipeline stage
  ///
  /// In en, this message translates to:
  /// **'Offline matching...'**
  String get scanStageOffline;

  /// Result screen title
  ///
  /// In en, this message translates to:
  /// **'Scan Result'**
  String get resultTitle;

  /// Confidence percentage
  ///
  /// In en, this message translates to:
  /// **'Confidence: {percentage}%'**
  String resultConfidence(double percentage);

  /// CTA button
  ///
  /// In en, this message translates to:
  /// **'Add to Collection'**
  String get resultAddToCollection;

  /// Alternative results header
  ///
  /// In en, this message translates to:
  /// **'Other matches'**
  String get resultAlternatives;

  /// No match state
  ///
  /// In en, this message translates to:
  /// **'No album found'**
  String get resultNoMatch;

  /// No match help text
  ///
  /// In en, this message translates to:
  /// **'Try a clearer photo, different angle, or search manually.'**
  String get resultNoMatchHint;

  /// Collection screen title
  ///
  /// In en, this message translates to:
  /// **'My Collection'**
  String get collectionTitle;

  /// Empty collection title
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get collectionEmpty;

  /// Empty collection subtitle
  ///
  /// In en, this message translates to:
  /// **'Scan your first album to start building your collection'**
  String get collectionEmptySubtitle;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search collection...'**
  String get collectionSearch;

  /// Album count label
  ///
  /// In en, this message translates to:
  /// **'{count} albums'**
  String collectionAlbumCount(int count);

  /// Tracklist section header
  ///
  /// In en, this message translates to:
  /// **'Tracklist'**
  String get albumTracklist;

  /// Genre label
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get albumGenre;

  /// Record label
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get albumLabel;

  /// Release year label
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get albumYear;

  /// Barcode label
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get albumBarcode;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Recognition'**
  String get settingsRecognition;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Online Recognition'**
  String get settingsOnlineRecognition;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'OCR Text Extraction'**
  String get settingsOcr;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Barcode Scanning'**
  String get settingsBarcode;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Visual Analysis'**
  String get settingsVisual;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get settingsOffline;

  /// Model management
  ///
  /// In en, this message translates to:
  /// **'Manage Models'**
  String get settingsManageModels;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get settingsHaptic;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// Settings link
  ///
  /// In en, this message translates to:
  /// **'Share & Export'**
  String get settingsShareExport;

  /// Settings link
  ///
  /// In en, this message translates to:
  /// **'Import Collection'**
  String get settingsImport;

  /// Destructive action
  ///
  /// In en, this message translates to:
  /// **'Clear Collection'**
  String get settingsClear;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Network error
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network settings.'**
  String get errorNoConnection;

  /// Timeout error
  ///
  /// In en, this message translates to:
  /// **'Server is not responding. Try again in a moment.'**
  String get errorTimeout;

  /// Rate limit error
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait a moment and try again.'**
  String get errorRateLimited;

  /// API no results
  ///
  /// In en, this message translates to:
  /// **'No album found. Try a photo from a different angle.'**
  String get errorNoResults;

  /// Low confidence
  ///
  /// In en, this message translates to:
  /// **'Recognition uncertain. Try a clearer photo.'**
  String get errorLowConfidence;

  /// Camera permission
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan albums.'**
  String get errorCamera;

  /// Generic fallback error
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorGeneric;

  /// Export format
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get exportJson;

  /// Export format
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get exportCsv;

  /// Export format
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get exportPdf;

  /// Import source
  ///
  /// In en, this message translates to:
  /// **'Discogs CSV'**
  String get importDiscogs;

  /// Import source
  ///
  /// In en, this message translates to:
  /// **'MusicBrainz JSON'**
  String get importMusicbrainz;

  /// Import source
  ///
  /// In en, this message translates to:
  /// **'Album Scanner JSON'**
  String get importGeneric;

  /// Import result title
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importComplete;

  /// Import stat
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get imported;

  /// Import stat
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get duplicates;

  /// Import stat
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// Onboarding
  ///
  /// In en, this message translates to:
  /// **'Scan Your Vinyl'**
  String get onboardingPage1Title;

  /// Onboarding
  ///
  /// In en, this message translates to:
  /// **'Point your camera at any album cover, barcode, or label'**
  String get onboardingPage1Subtitle;

  /// No description provided for @onboardingPage2Title.
  ///
  /// In en, this message translates to:
  /// **'Instant Recognition'**
  String get onboardingPage2Title;

  /// No description provided for @onboardingPage3Title.
  ///
  /// In en, this message translates to:
  /// **'Build Your Collection'**
  String get onboardingPage3Title;

  /// Onboarding
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Onboarding CTA
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// Stats screen
  ///
  /// In en, this message translates to:
  /// **'Collection Stats'**
  String get statsTitle;

  /// No description provided for @statsTotalAlbums.
  ///
  /// In en, this message translates to:
  /// **'Total Albums'**
  String get statsTotalAlbums;

  /// No description provided for @statsTotalArtists.
  ///
  /// In en, this message translates to:
  /// **'Total Artists'**
  String get statsTotalArtists;

  /// No description provided for @statsTotalGenres.
  ///
  /// In en, this message translates to:
  /// **'Total Genres'**
  String get statsTotalGenres;

  /// No description provided for @statsAvgConfidence.
  ///
  /// In en, this message translates to:
  /// **'Avg Confidence'**
  String get statsAvgConfidence;

  /// No description provided for @statsFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get statsFavorites;

  /// Wishlist screen
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlistTitle;

  /// Empty wishlist
  ///
  /// In en, this message translates to:
  /// **'Wishlist is empty'**
  String get wishlistEmpty;

  /// Manual add
  ///
  /// In en, this message translates to:
  /// **'Add Album'**
  String get wishlistAddManual;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Share button
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Done button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Loading indicator
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'pl':
      return SPl();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
