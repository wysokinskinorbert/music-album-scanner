# Architecture

## System Overview

Music Album Scanner is a Flutter-based Android application using **clean architecture** with
**BLoC pattern** for state management. The app is designed as **offline-first**, meaning all
core functionality works without network connectivity.

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ Screens  │  │ Widgets  │  │ BLoC (State Mgmt) │  │
│  └────┬─────┘  └────┬─────┘  └────────┬──────────┘  │
│       │              │                 │              │
├───────┼──────────────┼─────────────────┼──────────────┤
│       │           Domain               │              │
│  ┌────┴──────────────┴─────────────────┴──────────┐  │
│  │              Repository Layer                   │  │
│  │         (AlbumRepository interface)             │  │
│  └────────────────────┬───────────────────────────┘  │
│                       │                              │
├───────────────────────┼──────────────────────────────┤
│                    Data Layer                        │
│  ┌────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │   API      │  │     ML      │  │   Storage    │  │
│  │ Services   │  │  Services   │  │  Services    │  │
│  ├────────────┤  ├─────────────┤  ├──────────────┤  │
│  │MusicBrainz │  │ TFLite      │  │ Hive (local) │  │
│  │Discogs     │  │ Google ML   │  │ File System  │  │
│  │Cover Art   │  │ Kit         │  │              │  │
│  └────────────┘  └─────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Framework | Flutter 3.41+ | Cross-platform UI toolkit |
| Language | Dart 3.11+ | Type-safe, null-safe language |
| State Mgmt | flutter_bloc 9.x | Predictable state management |
| Local DB | Hive 2.x | Fast key-value NoSQL storage |
| Network | Dio 5.x | HTTP client with interceptors |
| ML Online | Google ML Kit | Image labeling / OCR |
| ML Offline | TFLite | On-device cover recognition |
| Camera | camera 0.11+ | Native camera access |
| Images | image 4.x | Cropping, resizing, processing |

## Data Flow

### Album Recognition Pipeline

```
User captures photo
        │
        ▼
┌───────────────────┐
│  Camera BLoC      │ ─── CapturePhoto event
└────────┬──────────┘
         │ imagePath
         ▼
┌───────────────────┐     ┌──────────────────────┐
│ Connectivity      │────▶│ Online or Offline?   │
│ Service           │     └──────────┬───────────┘
└───────────────────┘            ╱          \
                           ONLINE            OFFLINE
                              │                 │
                    ┌─────────▼──────┐  ┌───────▼────────┐
                    │ Google ML Kit  │  │ TFLite Model   │
                    │ (OCR/Labels)   │  │ (Cover Match)  │
                    └────────┬───────┘  └───────┬────────┘
                             │                  │
                    ┌────────▼──────┐           │
                    │ MusicBrainz   │           │
                    │ API Search    │           │
                    └────────┬──────┘           │
                             │                  │
                    ┌────────▼──────┐           │
                    │ Discogs API   │           │
                    │ (fallback)    │           │
                    └────────┬──────┘           │
                             ╲                ╱
                              ╲              ╱
                        ┌─────▼────────────▼─────┐
                        │  Recognition Result    │
                        │  (Album metadata)      │
                        └───────────┬────────────┘
                                    │
                        ┌───────────▼────────────┐
                        │  User Confirmation     │
                        │  (Scan Result Screen)  │
                        └───────────┬────────────┘
                                    │
                        ┌───────────▼────────────┐
                        │  Hive Local Storage    │
                        │  (Persistent save)     │
                        └────────────────────────┘
```

## Project Structure

```
lib/
├── main.dart                      # App entry, DI, providers
├── core/
│   ├── constants/
│   │   └── app_constants.dart     # All app-wide constants
│   ├── network/
│   │   ├── api_client.dart        # Dio wrapper with rate limiting
│   │   └── connectivity_service.dart
│   ├── theme/
│   │   ├── app_colors.dart        # Color palette (dark-first)
│   │   └── app_theme.dart         # Material 3 theme config
│   └── utils/                     # Utility functions
├── data/
│   ├── models/
│   │   ├── album_model.dart       # Album entity (Hive adapter)
│   │   ├── recognition_result.dart
│   │   └── scan_session.dart
│   ├── repositories/
│   │   └── album_repository.dart  # Repository pattern
│   └── services/
│       ├── api/
│       │   ├── musicbrainz_service.dart
│       │   └── discogs_service.dart
│       ├── ml/
│       │   └── offline_recognition_service.dart
│       ├── storage/
│       │   └── local_storage_service.dart
│       └── recognition_service.dart  # Orchestrator
├── features/
│   ├── camera/
│   │   ├── bloc/                  # Camera BLoC
│   │   ├── widgets/
│   │   └── scan_screen.dart
│   ├── collection/
│   │   ├── bloc/                  # Collection BLoC
│   │   ├── widgets/
│   │   │   └── album_card.dart
│   │   ├── collection_screen.dart
│   │   └── album_detail_screen.dart
│   ├── scan_result/
│   │   ├── bloc/                  # Scan Result BLoC
│   │   ├── widgets/
│   │   └── scan_result_screen.dart
│   ├── settings/
│   │   └── settings_screen.dart
│   └── home/
│       └── home_screen.dart       # Bottom nav shell
└── l10n/                          # Future i18n
```

## Key Design Decisions

### 1. BLoC over Riverpod/Provider
BLoC provides the most testable and structured state management for this scale of app.
Each feature has its own BLoC with clearly typed events and states, making the data flow
explicit and debuggable with the BLoC DevTools extension.

### 2. Offline-First with Hive
Hive provides sub-millisecond reads for the collection, works entirely offline, and supports
lazy loading. The app stores the user's photo alongside metadata, so the collection is fully
functional without any network.

### 3. Dual Recognition Strategy
- **Online**: Google ML Kit for OCR/labeling -> MusicBrainz search -> Discogs fallback
- **Offline**: TFLite MobileNet fine-tuned on album covers
- The system gracefully degrades: if online fails or is unavailable, offline kicks in.

### 4. One-Handed UX
- Bottom navigation within thumb reach
- Large capture button centered
- Primary actions (Save, Scan) as full-width bottom buttons
- Swipe-to-navigate between tabs

### 5. No Internal Database
The app has zero pre-loaded album data. All metadata comes from live API calls or the
downloadable ML model. The user's collection builds dynamically from their scans.

## API Dependencies

| Service | Endpoint | Rate Limit | Key Required |
|---------|----------|-----------|--------------|
| MusicBrainz | musicbrainz.org/ws/2 | 1 req/sec | No |
| Cover Art Archive | coverartarchive.org | Generous | No |
| Discogs | api.discogs.com | 25/min (60 with token) | Optional |
| Google ML Kit | On-device | Unlimited | No |

All APIs are free for commercial use within rate limits.
