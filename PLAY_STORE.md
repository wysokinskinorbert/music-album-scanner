# Google Play Store Preparation Checklist

## Assets Required

### App Icon
- 512x512 PNG - High-res icon for Play Store listing
- Adaptive icon (foreground + background) for Android 8+
- Location: android/app/src/main/res/

### Splash Screen
- Configured via flutter_native_splash
- Dark background matching app theme
- App logo centered

### Feature Graphic
- 1024x500 PNG - Banner at top of Play Store listing
- Shows app name + key visual

### Screenshots (minimum 2, max 8)
- Phone: 16:9 or 9:16 aspect ratio
- Recommended: Scan screen, Collection view, Album detail, Stats dashboard
- Minimum: 320px, Maximum: 3840px

## Store Listing

### Title (30 chars max)
Album Scanner - Vinyl Collection

### Short Description (80 chars max)
Scan album covers with your camera. Build and manage your vinyl collection.

### Full Description (4000 chars max)
Album Scanner helps you digitize and manage your physical music collection.

SCAN & RECOGNIZE
Point your camera at any album cover, barcode, or label. Our multi-strategy
recognition pipeline uses barcode scanning, OCR text extraction, and AI-powered
visual analysis to identify albums instantly.

OFFLINE CAPABLE
Download the recognition model and scan albums even without internet. Perfect
for record fairs and thrift stores with poor connectivity.

BUILD YOUR COLLECTION
Add scanned albums to your digital collection. Sort by artist, year, genre, or
label. Filter and search to find any album instantly.

RICH METADATA
Get complete album information including tracklist, release year, genre, record
label, and cover art from MusicBrainz and Discogs.

SHARE & EXPORT
Export your collection as JSON, CSV, or PDF. Share album cards to social media
or generate Instagram Stories with your latest finds.

IMPORT EXISTING COLLECTIONS
Import from Discogs CSV export or MusicBrainz to get started quickly.

KEY FEATURES:
- Camera-based album recognition
- Barcode (EAN-13, UPC-A) and OCR scanning
- Offline recognition with TFLite
- Image editing (crop, enhance, perspective correction)
- Collection statistics and duplicate detection
- Wishlist for albums you want to find
- Batch scanning for rapid cataloging
- Dark theme with Material 3 design

### Content Rating
- Everyone (no violence, no user-generated content, no social features)

### Category
- Primary: Music & Audio
- Secondary: Productivity

### Privacy Policy URL
Required before publication. Must be hosted publicly.

## Build Configuration

### Signing
```bash
# Generate keystore
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Reference in android/key.properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

### Build release
```bash
flutter build appbundle --release
```

### Version
Update in pubspec.yaml: version: 1.0.0+1
