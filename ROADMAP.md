# Roadmap

## v0.1.0 - Foundation
- [x] Flutter project scaffold with clean architecture
- [x] BLoC state management (Camera, Collection, ScanResult)
- [x] Dark theme with Material 3
- [x] MusicBrainz + Discogs API integration
- [x] Camera capture with gallery fallback
- [x] Hive local storage for collection
- [x] Album detail view with tracklist
- [x] Settings screen with export
- [x] GitHub repository initialized

## v0.2.0 - Core Recognition
- [x] Google ML Kit image labeling integration
- [x] OCR text extraction from album covers
- [x] Barcode/UPC scanning via camera
- [x] MusicBrainz search by extracted text
- [x] Discogs fallback when MusicBrainz fails
- [x] Cover Art Archive integration for cover art
- [x] Recognition confidence scoring
- [x] Manual search (artist + album input)
- [x] Recognition pipeline visualization (step-by-step progress)

## v0.3.0 - Offline Mode
- [x] Model download manager (download, cache, verify, delete)
- [x] TFLite inference service (MobileNet 224x224)
- [x] Cover embedding generator (512-dim feature vectors)
- [x] Offline embedding index (Hive-backed, up to 50K entries)
- [x] Cosine similarity matching against indexed covers
- [x] Offline-to-online sync service (enrich on reconnect)
- [x] Model versioning and update checker
- [x] Model download screen with progress UI
- [x] Offline badge + sync status bar widgets

## v0.4.0 - Image Editing
- [x] Image editor service (crop, rotate, flip, brightness, contrast, saturation, gamma)
- [x] Perspective correction with auto-detect corners + bilinear warp
- [x] Auto-enhancement with 7 preset modes
- [x] Image histogram analysis
- [x] OCR-optimized and ML-optimized enhancement
- [x] Interactive image editor screen (5 modes)
- [x] Before/after comparison with slider
- [x] Edit preview in scan flow

## v0.5.0 - Collection Management (Current)
- [x] Collection sort (7 fields: date, title, artist, year, genre, label, confidence)
- [x] Sort grouping for section headers
- [x] Collection filter (genre, decade, label, confidence, favorites, date range, search)
- [x] Genre/decade/label extraction from collection
- [x] Collection statistics dashboard (overview cards, scan methods, top artists/labels, genres, decades, recent additions)
- [x] Duplicate detection (MusicBrainz ID, barcode, exact match, fuzzy Jaccard bigram similarity)
- [x] Batch scan mode (multi-photo gallery picker, sequential processing, progress UI)
- [x] Wishlist (add/remove/mark found, manual input, search, swipe-to-delete)
- [x] Filter/Sort bottom sheet widget
- [x] Grid/List view toggle
- [x] Export collection event
- [x] Toggle favorite event
- [x] Updated Collection BLoC with ExportCollection + ToggleFavorite events

## v0.6.0 - Polish & UX
- [ ] Haptic feedback on scan events
- [ ] Animated transitions between screens
- [ ] Onboarding flow for new users
- [ ] Search suggestions / recent searches
- [ ] Swipe actions on collection items (delete, share)
- [ ] Widget for home screen (recently added)

## v0.7.0 - Sharing & Social
- [ ] Share album to Instagram stories format
- [ ] Generate collection infographic
- [ ] Export to CSV / PDF
- [ ] Import from Discogs collection
- [ ] Import from MusicBrainz collection

## v0.8.0 - Cloud Sync (Optional)
- [ ] Firebase / Supabase integration
- [ ] Cross-device sync
- [ ] Cloud backup / restore
- [ ] Optional user accounts

## v0.9.0 - Beta
- [ ] Full test coverage
- [ ] Performance profiling
- [ ] Accessibility audit
- [ ] i18n
- [ ] CI/CD pipeline
- [ ] Google Play Store preparation

## v1.0.0 - Production Release
- [ ] Google Play Store submission
- [ ] Privacy policy and terms
- [ ] Landing page
- [ ] Analytics and crash reporting
