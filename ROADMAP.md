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

## v0.2.0 - Core Recognition (Current)
- [x] Google ML Kit image labeling integration
- [x] OCR text extraction from album covers
- [x] Barcode/UPC scanning via camera
- [x] MusicBrainz search by extracted text
- [x] Discogs fallback when MusicBrainz fails
- [x] Cover Art Archive integration for cover art
- [x] Recognition confidence scoring
- [x] Manual search (artist + album input)
- [x] Recognition pipeline visualization (step-by-step progress)
- [x] Pipeline summary debug info

## v0.3.0 - Offline Mode
- [ ] TFLite model training/fine-tuning on album covers
- [ ] Model download manager in app
- [ ] On-device inference pipeline
- [ ] Offline-to-online sync when connectivity returns
- [ ] Model versioning and auto-updates

## v0.4.0 - Image Editing
- [ ] In-app crop tool for album photos
- [ ] Auto-enhancement (brightness, contrast for covers)
- [ ] Perspective correction for angled shots
- [ ] Photo comparison (original vs. enhanced)

## v0.5.0 - Collection Management
- [ ] Sort collection (by date, artist, year, genre)
- [ ] Filter by genre / decade / label
- [ ] Collection statistics dashboard
- [ ] Duplicate detection
- [ ] Batch scan mode (scan multiple albums in sequence)
- [ ] Wishlist for albums to find

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
- [ ] Optional user accounts (email, Google Sign-In)

## v0.9.0 - Beta
- [ ] Full test coverage (unit, widget, integration)
- [ ] Performance profiling and optimization
- [ ] Accessibility audit (TalkBack support)
- [ ] Multiple language support (i18n)
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Google Play Store preparation

## v1.0.0 - Production Release
- [ ] Google Play Store submission
- [ ] Privacy policy and terms of service
- [ ] Landing page / website
- [ ] Marketing materials
- [ ] Analytics and crash reporting (Firebase)
- [ ] In-app feedback mechanism
