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

## v0.6.0 - Polish & UX
- [x] Haptic feedback service (15+ events: scan, camera, duplicate, swipe, export)
- [x] Animated page transitions (shared axis horizontal/vertical/scaled, fade through)
- [x] Container transform for album card -> detail
- [x] Reusable animated widgets (FadeIn, SlideUp, ScaleIn)
- [x] Onboarding flow (3 pages)
- [x] Search suggestions service (Hive-backed)
- [x] Swipe action wrapper (delete left, share/favorite right)
- [x] Animated success/fail/scan indicators
- [x] Skeleton loading states

## v0.7.0 - Sharing & Social
- [x] Share service (text, text+image, album list, widget as image, clipboard)
- [x] Instagram Stories format generator (1080x1920)
- [x] Collection infographic generator
- [x] Export service (JSON, CSV, PDF)
- [x] Import service (Discogs CSV, MusicBrainz JSON, generic JSON)
- [x] Share/Export screen + Import screen

## v0.8.0 - Recognition Polish & Testing
- [x] Custom exception hierarchy + error mapper
- [x] Retry wrapper with exponential backoff + jitter
- [x] Diagnostics service (pipeline logging, aggregated stats)
- [x] Test suite: 200+ tests, 5200+ lines
- [x] Unit, BLoC, Widget tests
- [x] Empty state widget (8 variants) + Error banner + Photo quality indicator

## v0.9.0 - Beta Prep (Current)
- [x] CI/CD: GitHub Actions (analyze, test, build APK, upload artifact)
- [x] i18n: l10n.yaml config, ARB files (English + Polish, 90+ strings)
- [x] Performance service (timer-based metrics, percentile reports, auto-trim)
- [x] Accessibility service (semantic labels, contrast checker, min tap target)
- [x] Integration tests (app launch, tab navigation, scan flow, settings)
- [x] README.md (features, tech stack, setup, project structure, build guide)
- [x] Google Play Store preparation doc (listing, assets, signing, build)

## v0.10.0 - Cloud Sync (Deferred)
- [ ] Firebase / Supabase integration
- [ ] Cross-device sync
- [ ] Cloud backup / restore
- [ ] Optional user accounts

## v1.0.0 - Production Release
- [ ] App icon design (512x512)
- [ ] Splash screen design
- [ ] Screenshots for Play Store (4-8)
- [ ] Privacy policy (hosted)
- [ ] Google Play Store submission
- [ ] Landing page
