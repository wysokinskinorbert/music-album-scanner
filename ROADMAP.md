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
- [x] Recognition pipeline visualization

## v0.3.0 - Offline Mode
- [x] Model download manager (download, cache, verify, delete)
- [x] TFLite inference service (MobileNet 224x224)
- [x] Cover embedding generator (512-dim feature vectors)
- [x] Offline embedding index (Hive-backed, up to 50K entries)
- [x] Cosine similarity matching against indexed covers
- [x] Offline-to-online sync service
- [x] Model versioning and update checker
- [x] Model download screen + offline badge + sync status bar

## v0.4.0 - Image Editing
- [x] Image editor service (crop, rotate, flip, brightness, contrast, saturation, gamma)
- [x] Perspective correction with auto-detect + bilinear warp
- [x] Auto-enhancement with 7 preset modes
- [x] Interactive image editor screen (5 modes)
- [x] Before/after comparison with slider
- [x] Edit preview in scan flow

## v0.5.0 - Collection Management
- [x] Collection sort (7 fields) + grouping
- [x] Collection filter (genre, decade, label, confidence, favorites, date range)
- [x] Collection statistics dashboard
- [x] Duplicate detection (4 methods: MBID, barcode, exact, fuzzy Jaccard)
- [x] Batch scan mode
- [x] Wishlist (add/remove/mark found/manual input)
- [x] Filter/Sort bottom sheet + grid/list toggle

## v0.6.0 - Polish & UX (Current)
- [x] Haptic feedback service (15+ events: scan, camera, duplicate, swipe, export)
- [x] Animated page transitions (shared axis horizontal/vertical/scaled, fade through)
- [x] Container transform for album card -> detail
- [x] Reusable animated widgets (FadeIn, SlideUp, ScaleIn)
- [x] Onboarding flow (3 pages: Scan Your Vinyl, Instant Recognition, Build Your Collection)
- [x] First-launch detection (SharedPreferences)
- [x] Search suggestions service (Hive-backed, 50 entries max)
- [x] Search bar widget with recent searches dropdown
- [x] Swipe action wrapper (delete left, share/favorite right)
- [x] Animated success indicator (elastic scale + checkmark draw)
- [x] Animated fail indicator (elastic scale + rotation)
- [x] Animated scan pulse (breathing circle)
- [x] Skeleton loading states (album card, list item, grid, stats, pipeline)
- [x] Updated main.dart with onboarding check + haptic init
- [x] Updated home screen with polished nav bar (gradient scan button)

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
