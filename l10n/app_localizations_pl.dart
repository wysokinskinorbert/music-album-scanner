// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class SPl extends S {
  SPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Album Scanner';

  @override
  String get tabCollection => 'Kolekcja';

  @override
  String get tabScan => 'Skanuj';

  @override
  String get tabSettings => 'Ustawienia';

  @override
  String get tabWishlist => 'Lista zyczen';

  @override
  String get scanTitle => 'Skanuj album';

  @override
  String get scanInstructions =>
      'Skieruj kamere na okladke albumu lub kod kreskowy';

  @override
  String get scanButton => 'Skanuj';

  @override
  String get scanGalleryButton => 'Wybierz z galerii';

  @override
  String get scanManualButton => 'Szukaj recznie';

  @override
  String get scanProcessing => 'Analizuje...';

  @override
  String get scanStageBarcode => 'Skanowanie kodu kreskowego...';

  @override
  String get scanStageOcr => 'Odczytywanie tekstu...';

  @override
  String get scanStageLabeling => 'Analiza okladki...';

  @override
  String get scanStageSearch => 'Przeszukiwanie baz danych...';

  @override
  String get scanStageOffline => 'Dopasowanie offline...';

  @override
  String get resultTitle => 'Wynik skanowania';

  @override
  String resultConfidence(double percentage) {
    final intl.NumberFormat percentageNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentageString = percentageNumberFormat.format(percentage);

    return 'Pewnosc: $percentageString%';
  }

  @override
  String get resultAddToCollection => 'Dodaj do kolekcji';

  @override
  String get resultAlternatives => 'Inne dopasowania';

  @override
  String get resultNoMatch => 'Nie znaleziono albumu';

  @override
  String get resultNoMatchHint =>
      'Sprobuj wyrazniejszejszego zdjecia, innego kat lub wyszukiwania recznego.';

  @override
  String get collectionTitle => 'Moja kolekcja';

  @override
  String get collectionEmpty => 'Brak albumow';

  @override
  String get collectionEmptySubtitle =>
      'Zeskanuj pierwszy album, aby zbudowac kolekcje';

  @override
  String get collectionSearch => 'Szukaj w kolekcji...';

  @override
  String collectionAlbumCount(int count) {
    return '$count albumow';
  }

  @override
  String get albumTracklist => 'Lista utworow';

  @override
  String get albumGenre => 'Gatunek';

  @override
  String get albumLabel => 'Wytwornia';

  @override
  String get albumYear => 'Rok';

  @override
  String get albumBarcode => 'Kod kreskowy';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsRecognition => 'Rozpoznawanie';

  @override
  String get settingsOnlineRecognition => 'Rozpoznawanie online';

  @override
  String get settingsOcr => 'Ekstrakcja tekstu OCR';

  @override
  String get settingsBarcode => 'Skanowanie kodu kreskowego';

  @override
  String get settingsVisual => 'Analiza wizualna';

  @override
  String get settingsOffline => 'Tryb offline';

  @override
  String get settingsManageModels => 'Zarzadzanie modelami';

  @override
  String get settingsHaptic => 'Dotyk haptyczny';

  @override
  String get settingsData => 'Dane';

  @override
  String get settingsShareExport => 'Udostepnij i eksportuj';

  @override
  String get settingsImport => 'Importuj kolekcje';

  @override
  String get settingsClear => 'Wyczysc kolekcje';

  @override
  String get settingsAbout => 'O aplikacji';

  @override
  String get settingsVersion => 'Wersja';

  @override
  String get errorNoConnection =>
      'Brak polaczenia z internetem. Sprawdz ustawienia sieci.';

  @override
  String get errorTimeout =>
      'Serwer nie odpowiada. Sprobuj ponownie za chwile.';

  @override
  String get errorRateLimited =>
      'Zbyt wiele zapytan. Odczekaj chwile i sprobuj ponownie.';

  @override
  String get errorNoResults =>
      'Nie znaleziono albumu. Sprobuj zdjecie z innej strony.';

  @override
  String get errorLowConfidence =>
      'Rozpoznanie niepewne. Sprobuj wyrazniejszejszego zdjecia.';

  @override
  String get errorCamera => 'Wymagane zezwolenie na dostep do kamery.';

  @override
  String get errorGeneric => 'Wystapil nieoczekiwany blad. Sprobuj ponownie.';

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
  String get importComplete => 'Import zakonczony';

  @override
  String get imported => 'Zaimportowano';

  @override
  String get duplicates => 'Duplikaty';

  @override
  String get skipped => 'Pominiete';

  @override
  String get onboardingPage1Title => 'Zeskanuj vinyle';

  @override
  String get onboardingPage1Subtitle =>
      'Skieruj kamere na dowolna okladke, kod kreskowy lub etykiete';

  @override
  String get onboardingPage2Title => 'Natychmiastowe rozpoznanie';

  @override
  String get onboardingPage3Title => 'Zbuduj kolekcje';

  @override
  String get onboardingSkip => 'Pomin';

  @override
  String get onboardingGetStarted => 'Zacznij';

  @override
  String get statsTitle => 'Statystyki kolekcji';

  @override
  String get statsTotalAlbums => 'Lacznie albumow';

  @override
  String get statsTotalArtists => 'Lacznie artystow';

  @override
  String get statsTotalGenres => 'Lacznie gatunkow';

  @override
  String get statsAvgConfidence => 'Srednia pewnosc';

  @override
  String get statsFavorites => 'Ulubione';

  @override
  String get wishlistTitle => 'Lista zyczen';

  @override
  String get wishlistEmpty => 'Lista zyczen jest pusta';

  @override
  String get wishlistAddManual => 'Dodaj album';

  @override
  String get retry => 'Ponow';

  @override
  String get cancel => 'Anuluj';

  @override
  String get delete => 'Usun';

  @override
  String get share => 'Udostepnij';

  @override
  String get save => 'Zapisz';

  @override
  String get done => 'Gotowe';

  @override
  String get loading => 'Ladowanie...';
}
