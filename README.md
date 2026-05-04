# Album Scanner

A mobile app for recognizing music albums via camera, retrieving full metadata, and managing a physical album collection digitally.

Built with Flutter, designed for Android (API 26+).

## Features

- **Camera Recognition** - Point at any album cover, barcode, or label
- **Multi-Strategy Pipeline** - Barcode scanning, OCR text extraction, ML Kit visual analysis
- **API Integration** - MusicBrainz (primary) + Discogs (fallback) + Cover Art Archive
- **Offline Mode** - TFLite MobileNet for offline recognition + cosine similarity matching
- **Image Editor** - Crop, perspective correction, auto-enhance before recognition
- **Collection Management** - Sort, filter, stats, duplicate detection, batch scan
- **Wishlist** - Track albums you want to find
- **Share & Export** - JSON/CSV/PDF export, Instagram Stories, share to any app
- **Import** - Discogs CSV, MusicBrainz JSON, Album Scanner JSON
- **Polish** - Haptic feedback, animations, onboarding, skeleton loading, dark theme

## Screenshots

> Screenshots will be added before Play Store submission.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.24+ (Dart) |
| State Management | flutter_bloc (BLoC pattern) |
| Architecture | Clean Architecture (Presentation -> Domain -> Data) |
| Local Storage | Hive |
| Networking | Dio |
| ML/Recognition | Google ML Kit, TFLite MobileNet |
| APIs | MusicBrainz, Discogs, Cover Art Archive |
| Image Processing | image package |
| CI/CD | GitHub Actions |

## Getting Started

### Prerequisites

- Flutter SDK 3.24+ ([install](https://docs.flutter.dev/get-started/install))
- Android SDK (API 26+)
- Android Studio or VS Code

### Setup

```bash
# Clone the repository
git clone https://github.com/wysokinskinorbert/music-album-scanner.git
cd music-album-scanner

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run on connected device/emulator
flutter run
```

### Running Tests

```bash
# Unit + widget tests
flutter test

# With coverage
flutter test --coverage

# Integration tests (requires connected device)
flutter test integration_test/
```

### Building APK

```bash
flutter build apk --release
```

## Project Structure

```
lib/
  core/           # Theme, network, errors, services
  data/           # Models, API services, repositories, ML services
  features/       # Feature modules (screens, BLoC, widgets)
    camera/       # Camera + scan flow
    collection/   # Collection management
    home/         # Home screen + navigation
    settings/     # App settings
    sharing/      # Share + export
    import_export/# Import
    common/       # Shared widgets (empty states, error banner)
  main.dart       # Entry point with onboarding gate

test/             # Unit + widget tests (200+ tests)
integration_test/ # E2E integration tests
l10n/             # i18n ARB files (EN, PL)
```

## Architecture

```
Presentation (Screens, Widgets, BLoC)
         |
      Domain (Models, Repository Interfaces)
         |
       Data (API Services, Storage, ML Services, Repositories)
```

## API Keys

- **MusicBrainz**: Free, no key required (1 req/sec rate limit)
- **Discogs**: Free tier (25 req/min), optional personal token for higher limits (60 req/min)
- **Cover Art Archive**: Free, no key required

No API keys are needed for basic functionality. Discogs token can be configured in Settings.

## License

MIT License - see [LICENSE](LICENSE)

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full development roadmap.

## Contributing

This is a personal project, but suggestions and bug reports are welcome via GitHub Issues.
