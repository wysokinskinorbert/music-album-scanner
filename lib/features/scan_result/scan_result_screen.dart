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
      create: (context) => ScanResultBloc(
        recognitionService: RepositoryProvider.of(context),
        albumRepository: RepositoryProvider.of(context),
      )..add(StartRecognition(imagePath: imagePath)),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          title: const Text('Scan Result'),
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
        ),
        body: BlocBuilder<ScanResultBloc, ScanResultState>(
          builder: (context, state) {
            if (state is ScanResultProcessing) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF7C3AED)),
                    const SizedBox(height: 24),
                    Text(state.stage ?? 'Recognizing album...',
                        style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              );
            } else if (state is ScanResultSuccess) {
              return _AlbumResultCard(album: state.album);
            } else if (state is ScanResultMultipleMatches) {
              return _MultipleMatchesList(albums: state.albums);
            } else if (state is ScanResultFailure) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 16),
                    Text(state.message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.read<ScanResultBloc>().add(RetryRecognition()),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            } else if (state is ScanResultSaved) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 64),
                    const SizedBox(height: 16),
                    const Text('Album saved!', style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      child: const Text('Back'),
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
                child: Image.network(album.coverArtUrl!, height: 200, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        height: 200, color: const Color(0xFF1A1A2E),
                        child: const Icon(Icons.album, size: 80, color: Color(0xFF7C3AED)))),
              ),
            ),
          const SizedBox(height: 20),
          Text(album.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(album.artist, style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 18)),
          if (album.releaseYear != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Year: ${album.releaseYear}', style: const TextStyle(color: Colors.white70))),
          if (album.genre != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Genre: ${album.genre}', style: const TextStyle(color: Colors.white70))),
          if (album.label != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Label: ${album.label}', style: const TextStyle(color: Colors.white70))),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => context.read<ScanResultBloc>().add(ConfirmAndSave(album: album)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                child: const Text('Add to Collection'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultipleMatchesList extends StatelessWidget {
  final List<Album> albums;
  const _MultipleMatchesList({required this.albums});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return Card(
          color: const Color(0xFF1A1A2E),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: album.coverArtUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(album.coverArtUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.album, color: Color(0xFF7C3AED))))
                : const Icon(Icons.album, color: Color(0xFF7C3AED)),
            title: Text(album.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text('${album.artist}${album.releaseYear != null ? ' (${album.releaseYear})' : ''}', style: const TextStyle(color: Colors.white54)),
            onTap: () => context.read<ScanResultBloc>().add(SelectResult(album: album)),
          ),
        );
      },
    );
  }
}
