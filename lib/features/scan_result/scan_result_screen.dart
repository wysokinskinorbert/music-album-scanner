import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/scan_result_bloc.dart';
import '../../../data/models/album_model.dart';

class ScanResultScreen extends StatelessWidget {
  final String imagePath;

  const ScanResultScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScanResultBloc()..add(StartScan(imagePath: imagePath)),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          title: const Text('Scan Result'),
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
        ),
        body: BlocBuilder<ScanResultBloc, ScanResultState>(
          builder: (context, state) {
            if (state is ScanResultLoading) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF7C3AED)),
                    SizedBox(height: 24),
                    Text('Recognizing album...', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              );
            } else if (state is ScanResultSuccess) {
              return _AlbumResultCard(album: state.album);
            } else if (state is ScanResultError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 16),
                    Text(state.message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: Text('Ready to scan', style: TextStyle(color: Colors.white54)));
          },
        ),
      ),
    );
  }
}

class _AlbumResultCard extends StatelessWidget {
  final Album album;
  const _AlbumResultCard({required this.album});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (album.coverArtUrl != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(album.coverArtUrl!, height: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => 
                  Container(height: 200, color: const Color(0xFF1A1A2E), child: const Icon(Icons.album, size: 80, color: Color(0xFF7C3AED)))),
              ),
            ),
          const SizedBox(height: 20),
          Text(album.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(album.artist, style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 18)),
          if (album.releaseYear != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Year: \${album.releaseYear}', style: const TextStyle(color: Colors.white70))),
          if (album.genre != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Genre: \${album.genre}', style: const TextStyle(color: Colors.white70))),
          if (album.label != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Label: \${album.label}', style: const TextStyle(color: Colors.white70))),
          if (album.tracklist.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Tracklist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...album.tracklist.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('\${e.key + 1}. \${e.value}', style: const TextStyle(color: Colors.white54)),
            )),
          ],
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text('Add to Collection', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
