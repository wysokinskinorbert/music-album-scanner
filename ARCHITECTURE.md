# Architecture

## System Overview

Music Album Scanner is a Flutter-based Android application using **clean architecture** with
**BLoC pattern** for state management. The app is designed as **offline-first**, meaning all
core functionality works without network connectivity.

```
+-----------------------------------------------------+
|                    Presentation                      |
|  +----------+  +----------+  +-------------------+  |
|  | Screens  |  | Widgets  |  | BLoC (State Mgmt) |  |
|  +----+-----+  +----+-----+  +--------+----------+  |
|       |              |                 |              |
+-------+--------------+-----------------+--------------+
|       |           Domain               |              |
|  +----+--------------+-----------------+----------+  |
|  |              Repository Layer                   |  |
|  |         (AlbumRepository interface)             |  |
|  +--------------------+---------------------------+  |
|                       |                              |
+-----------------------+------------------------------+
|                    Data Layer                        |
|  +------------+  +-------------+  +--------------+  |
|  |   API      |  |     ML      |  |   Storage    |  |
|  | Services   |  |  Services   |  |  Services    |  |
|  +------------+  +-------------+  +--------------+  |
|  |MusicBrainz |  | Google ML   |  | Hive (local) |  |
|  |Discogs     |  |  - OCR      |  | File System  |  |
|  |Cover Art   |  |  - Labels   |  |              |  |
|  | Archive    |  |  - Barcode  |  |              |  |
|  |            |  | TFLite      |  |              |  |
|  +------------+  +-------------+  +--------------+  |
+-----------------------------------------------------+
```

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Framework | Flutter 3.41+ | Cross-platform UI toolkit |
| Language | Dart 3.11+ | Type-safe, null-safe language |
| State Mgmt | flutter_bloc 9.x | Predictable state management |
| Local DB | Hive 2.x | Fast key-value NoSQL storage |
| Network | Dio 5.x | HTTP client with interceptors |
| ML OCR | Google ML Kit Text Recognition | Extract text from covers |
| ML Labels | Google ML Kit Image Labeling | Identify visual elements |
| ML Barcode | Google ML Kit Barcode Scanning | EAN-13 / UPC-A scanning |
| ML Offline | TFLite | On-device cover recognition |
| Camera | camera 0.11+ | Native camera access |
| Images | image 4.x | Cropping, resizing, processing |

## Data Flow

### Album Recognition Pipeline (v0.2.0)

The recognition pipeline is a multi-strategy orchestrator that tries increasingly
sophisticated approaches until it finds a confident match:

```
User captures photo
        |
        v
+-------------------+
|  Barcode Scanner  |---- Scan EAN-13/UPC-A
|  (ML Kit)         |
+--------+----------+
         | barcode found?
    YES /   \ NO
       /     \
      v       v
MusicBrainz   +-------------------+
Barcode       |  OCR Text         |
Lookup        |  (ML Kit)         |
              |  Extract all text |
              +--------+----------+
                       |
                       v
              +-------------------+
              |  Generate Search  |
              |  Queries          |
              |  (multi-strategy) |
              +--------+----------+
                       |
                       v
              +-------------------+
              |  MusicBrainz      |
              |  Search           |
              +--------+----------+
                  |    |
           FOUND  |    | NOT FOUND
                  v    v
              +------+----------+
              |  Discogs         |
              |  Fallback Search |
              +--------+---------+
                       |
                       v
              +-------------------+
              |  Visual Analysis  |---- ML Kit Image Labeling
              |  (if no text)     |---- Cover type classification
              +--------+----------+
                       |
                       v
              +-------------------+
              |  Offline Model    |---- TFLite MobileNet
              |  (if downloaded)  |
              +--------+----------+
                       |
                       v
              +-------------------+
              |  Enrichment       |---- Cover Art Archive
              |                   |---- Full tracklist
              |                   |---- Genre/country/label
              +--------+----------+
                       |
                       v
              +-------------------+
              |  User Confirm     |---- Confidence badge
              |                   |---- Pipeline summary
              +--------+----------+
                       |
                       v
              +-------------------+
              |  Save to Hive     |
              |  (local storage)  |
              +-------------------+
```

### Recognition Pipeline Strategies

| Priority | Strategy | Input | API | Accuracy | Speed |
|----------|----------|-------|-----|----------|-------|
| 1 | Barcode | EAN/UPC | MusicBrainz | ~95% | Fast |
| 2 | OCR + Search | Extracted text | MusicBrainz | ~80% | Medium |
| 3 | OCR + Search | Extracted text | Discogs | ~75% | Medium |
| 4 | Visual Labels | Cover analysis | Context search | ~60% | Slow |
| 5 | Offline Model | Cover image | TFLite | ~50% | Fast |

### OCR Query Generation

The text extraction service generates multiple search queries from OCR results:

1. **First line** - Likely album title
2. **First two lines** - Artist + title combination
3. **All text (up to 4 lines)** - For text-heavy covers
4. **Largest text block** - Heuristic for prominent title

### Confidence Scoring

Confidence is calculated per-strategy:

| Source | Confidence | Logic |
|--------|-----------|-------|
| Barcode + MusicBrainz match | 0.95 | Exact barcode match |
| Barcode + Discogs match | 0.90 | Barcode but different DB |
| OCR + MusicBrainz (single result) | 0.85 | One clear match |
| OCR + MusicBrainz (multiple similar) | 0.90 | Results agree |
| OCR + MusicBrainz (diverse) | 0.80 | Different results |
| OCR + Discogs | 0.75 | Fallback DB |
| Visual labels + search | 0.60 | Indirect match |
| Offline model | 0.50 | Unconfirmed |

Threshold: **0.70** (below this, show failure state with retry options)

## Project Structure

```
lib/
+-- main.dart                      # App entry, DI, providers
+-- core/
|   +-- constants/
|   |   +-- app_constants.dart     # All app-wide constants
|   +-- network/
|   |   +-- api_client.dart        # Dio wrapper with rate limiting
|   |   +-- connectivity_service.dart
|   +-- theme/
|   |   +-- app_colors.dart        # Color palette (dark-first)
|   |   +-- app_theme.dart         # Material 3 theme config
|   +-- utils/                     # Utility functions
+-- data/
|   +-- models/
|   |   +-- album_model.dart       # Album entity (Hive adapter)
|   |   +-- recognition_result.dart
|   |   +-- scan_session.dart
|   +-- repositories/
|   |   +-- album_repository.dart  # Repository pattern
|   +-- services/
|       +-- api/
|       |   +-- musicbrainz_service.dart
|       |   +-- discogs_service.dart
|       +-- ml/
|       |   +-- text_extraction_service.dart   # OCR (v0.2.0)
|       |   +-- image_labeling_service.dart    # Visual analysis (v0.2.0)
|       |   +-- barcode_scanning_service.dart  # EAN/UPC (v0.2.0)
|       |   +-- offline_recognition_service.dart
|       +-- recognition_service.dart  # Pipeline orchestrator
|       +-- storage/
|           +-- local_storage_service.dart
+-- features/
    +-- camera/
    |   +-- bloc/                  # Camera BLoC
    |   +-- scan_screen.dart       # Camera UI
    +-- collection/
    |   +-- bloc/                  # Collection BLoC
    |   +-- collection_screen.dart
    |   +-- album_detail_screen.dart
    |   +-- widgets/
    |       +-- album_card.dart
    +-- scan_result/
    |   +-- bloc/                  # Scan Result BLoC (pipeline-aware)
    |   +-- scan_result_screen.dart  # Result UI with pipeline viz
    |   +-- manual_search_screen.dart # Text search (v0.2.0)
    +-- settings/
    |   +-- settings_screen.dart
    +-- home/
        +-- home_screen.dart       # Bottom nav shell
```

## Key Design Decisions

### 1. Multi-Strategy Pipeline
Instead of relying on a single recognition method, the app chains multiple strategies.
Barcode is tried first (fastest, most accurate), then OCR, then visual analysis,
then offline model. The pipeline stops at the first high-confidence result.

### 2. Google ML Kit Over Custom Models
ML Kit runs entirely on-device, requires no API keys, and provides three critical
capabilities (OCR, labeling, barcode) in a single dependency. This is optimal for
the commercial-free requirement.

### 3. MusicBrainz Before Discogs
MusicBrainz has richer structured data (relationships, detailed release events)
and requires no authentication. Discogs is used as fallback with optional token
for higher rate limits.

### 4. Pipeline Visualization
The scan result screen shows step-by-step progress (4 dots) and a pipeline summary
string like "Barcode Scan: FAIL -> OCR: OK (85%)". This helps users understand
what happened and trust the results.

### 5. Graceful Degradation
If camera fails -> show manual search. If online fails -> try offline model.
If everything fails -> show extracted text and offer retry or manual search.
The user always has a path forward.

## API Dependencies

| Service | Endpoint | Rate Limit | Key Required | Commercial |
|---------|----------|-----------|--------------|-----------|
| MusicBrainz | musicbrainz.org/ws/2 | 1 req/sec | No | Yes (CC0) |
| Cover Art Archive | coverartarchive.org | Generous | No | Yes (CC0) |
| Discogs | api.discogs.com | 25/min (60 w/ token) | Optional | Yes |
| Google ML Kit | On-device | Unlimited | No | Yes |
