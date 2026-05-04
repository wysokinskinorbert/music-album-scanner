import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/album.dart';

/// Generates Instagram Stories-ready images from album data.
/// Output: 1080x1920 portrait image with album cover + gradient overlay.
class InstagramStoriesGenerator {
  static const _width = 1080.0;
  static const _height = 1920.0;

  /// Generate a stories image and return the file path.
  Future<String?> generate({
    required Album album,
    required GlobalKey repaintKey,
  }) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final filePath = '\${tempDir.path}/ig_story_\${album.id}.png';
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return filePath;
    } catch (e) {
      return null;
    }
  }
}

/// Widget that renders an Instagram Stories-ready card.
/// This widget is captured to PNG for sharing.
class InstagramStoryCard extends StatelessWidget {
  final Album album;
  final File? coverImage;

  const InstagramStoryCard({
    super.key,
    required this.album,
    this.coverImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: InstagramStoriesGenerator._width,
      height: InstagramStoriesGenerator._height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0E1A),
            Color(0xFF1A1040),
            Color(0xFF7C3AED),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Background album art (blurred)
          if (coverImage != null)
            Positioned.fill(
              child: Image.file(
                coverImage!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.5),
                colorBlendMode: BlendMode.darken,
              ),
            ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  const SizedBox(height: 120),

                  // Album cover
                  if (coverImage != null)
                    Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(coverImage!, fit: BoxFit.cover),
                      ),
                    )
                  else
                    Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.album, size: 120, color: AppColors.textTertiary),
                    ),

                  const SizedBox(height: 60),

                  // Album info
                  Text(
                    album.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    album.artist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (album.year != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      album.year.toString(),
                      style: TextStyle(
                        color: AppColors.accent.withOpacity(0.9),
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (album.genre != null && album.genre!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        album.genre!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // App branding
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.album, color: AppColors.accent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Album Scanner',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
