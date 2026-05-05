import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/album_model.dart';

/// Service for sharing album data and images.
class ShareService {
  /// Share album info as text.
  Future<void> shareAlbumText(Album album) async {
    final text = _formatAlbumText(album);
    await Share.share(text, subject: '\${album.title} - \${album.artist}');
  }

  /// Share album info with cover image.
  Future<void> shareAlbumWithImage(Album album) async {
    final imagePath = album.userPhotoPath ?? album.coverArtUrl;
    if (imagePath == null || imagePath.isEmpty) {
      return shareAlbumText(album);
    }

    final text = _formatAlbumText(album);
    final imageFile = File(imagePath);
    if (await imageFile.exists()) {
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: text,
        subject: '\${album.title} - \${album.artist}',
      );
    } else {
      await Share.share(text);
    }
  }

  /// Share multiple albums as a list.
  Future<void> shareAlbumList(List<Album> albums) async {
    final buffer = StringBuffer();
    buffer.writeln('My Album Collection');
    buffer.writeln('=' * 30);
    buffer.writeln();

    for (int i = 0; i < albums.length; i++) {
      final a = albums[i];
      buffer.writeln('\${i + 1}. \${a.artist} - \${a.title}');
      if (a.year != null) buffer.writeln('   Year: \${a.year}');
      if (a.genre != null && a.genre!.isNotEmpty) {
        buffer.writeln('   Genre: \${a.genre}');
      }
      if (a.label != null) buffer.writeln('   Label: \${a.label}');
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('Total: \${albums.length} albums');
    buffer.writeln('Shared via Album Scanner');

    await Share.share(buffer.toString(), subject: 'My Album Collection');
  }

  /// Share a rendered widget as image (for Instagram stories, infographics).
  Future<void> shareWidgetAsImage({
    required GlobalKey repaintKey,
    String? text,
    String? subject,
  }) async {
    final image = await _captureWidget(repaintKey);
    if (image == null) return;

    final tempDir = await getTemporaryDirectory();
    final filePath = '\${tempDir.path}/share_\${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(filePath);
    await file.writeAsBytes(image);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: text ?? '',
      subject: subject,
    );
  }

  /// Copy album info to clipboard.
  Future<void> copyAlbumToClipboard(Album album) async {
    final text = _formatAlbumText(album);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Capture a widget as PNG bytes.
  Future<Uint8List?> _captureWidget(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Format album as readable text.
  String _formatAlbumText(Album album) {
    final buffer = StringBuffer();
    buffer.writeln('\${album.artist} - \${album.title}');

    if (album.year != null) buffer.writeln('Year: \${album.year}');
    if (album.genre != null && album.genre!.isNotEmpty) {
      buffer.writeln('Genre: \${album.genre}');
    }
    if (album.label != null) buffer.writeln('Label: \${album.label}');

    if (album.tracklist.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Tracklist:');
      for (int i = 0; i < album.tracklist.length; i++) {
        buffer.writeln('  \${i + 1}. \${album.tracklist[i]}');
      }
    }

    buffer.writeln();
    buffer.writeln('Scanned with Album Scanner');

    return buffer.toString();
  }
}
