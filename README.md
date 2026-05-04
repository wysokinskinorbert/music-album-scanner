# Music Album Scanner

An AI-powered Android application for music album recognition and collection management.

Scan physical album covers with your camera, identify them using machine learning,
and build a digital catalog of your music collection.

## Features

- **Camera Recognition** - Point your camera at any album cover to identify it
- **Dual Engine** - Online (MusicBrainz + Discogs) and offline (TFLite) recognition
- **Artistic Covers** - Recognizes covers without text or barcodes using visual matching
- **Rich Metadata** - Artist, title, tracklist, year, label, genre, and cover art
- **Offline-First** - Your collection works fully without internet
- **Image Editor** - Crop and enhance photos before recognition
- **One-Handed UX** - Bottom navigation, large buttons, swipe gestures
- **Export** - Share your collection as JSON or CSV
- **No Registration** - Works out of the box, no account needed

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.41+ (Dart 3.11+) |
| State Management | flutter_bloc |
| Local Storage | Hive |
| Network | Dio |
| ML Online | Google ML Kit |
| ML Offline | TFLite |
| Camera | camera plugin |

## Getting Started

### Prerequisites
- Flutter SDK 3.41+ (stable channel)
- Android SDK (API 26+)
- Android Studio or VS Code with Flutter extension

### Setup

```bash
# Clone the repository
git clone https://github.com/wysokinskinorbert/music-album-scanner.git
cd music-album-scanner

# Install dependencies
flutter pub get

# Run code generation (Hive adapters)
dart run build_runner build

# Run the app
flutter run
```

### Building APK

```bash
flutter build apk --release
```

## Architecture

The app follows **Clean Architecture** with three layers:

```
Presentation (Screens + BLoC) → Domain (Repositories) → Data (APIs + Storage)
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed system design.

## Project Structure

```
lib/
├── core/           # Theme, constants, network, utilities
├── data/           # Models, repositories, services (API, ML, storage)
├── features/       # Feature modules (camera, collection, scan_result, settings)
│   ├── bloc/       # BLoC events, states, and logic
│   ├── widgets/    # Feature-specific UI components
│   └── *_screen.dart  # Feature screens
└── main.dart       # App entry point
```

## API Usage

This app uses free, commercially-available APIs:

| API | Purpose | Key Required |
|-----|---------|-------------|
| [MusicBrainz](https://musicbrainz.org) | Album metadata | No |
| [Cover Art Archive](https://coverartarchive.org) | Cover art images | No |
| [Discogs](https://www.discogs.com) | Fallback metadata | Optional |
| Google ML Kit | On-device OCR/labeling | No |

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features and milestones.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Built by [wysokinskinorbert](https://github.com/wysokinskinorbert)
