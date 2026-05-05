import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/album_model.dart';
import '../../../data/services/recognition_service.dart';
import '../../../data/repositories/album_repository.dart';
import 'bloc/scan_result_bloc.dart';

class ScanResultScreen extends StatelessWidget {
  final String imagePath;

  const ScanResultScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocProvider(
        create: (context) => ScanResultBloc(
          recognition: context.read<RecognitionService>(),
          repository: context.read<AlbumRepository>(),
        )..add(StartRecognition(imagePath)),
        child: BlocBuilder<ScanResultBloc, ScanResultState>(
          builder: (context, state) {
            if (state is ScanResultProcessing) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(state.currentStep),
                  ],
                ),
              );
            } else if (state is ScanResultSuccess) {
              return _AlbumDetail(
                album: state.album,
                confidence: state.confidence,
                source: state.source,
                onSave: () {
                  context.read<ScanResultBloc>().add(ConfirmAndSave(album: state.album));
                },
              );
            } else if (state is ScanResultSaved) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text('Album saved to collection!'),
                    const SizedBox(height: 16),
                    Text(state.album.title),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              );
            } else if (state is ScanResultFailure) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.message),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ScanResultBloc>().add(RetryRecognition(imagePath));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: Text('Ready to scan'));
          },
        ),
      ),
    );
  }
}

class _AlbumDetail extends StatelessWidget {
  final Album album;
  final double confidence;
  final String source;
  final VoidCallback onSave;

  const _AlbumDetail({
    required this.album,
    this.confidence = 0.0,
    this.source = 'unknown',
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (album.coverArtUrl != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  album.coverArtUrl!,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    width: 250,
                    color: Colors.grey[800],
                    child: const Icon(Icons.album, size: 80),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            album.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            album.artist,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
          if (album.releaseYear != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Year: ${album.releaseYear}'),
            ),
          if (album.label != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Label: ${album.label}'),
            ),
          if (album.genre != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Genre: ${album.genre}'),
            ),
          if (album.country != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Country: ${album.country}'),
            ),
          if (album.barcode != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Barcode: ${album.barcode}'),
            ),
          const SizedBox(height: 8),
          Text(
            'Confidence: ${(confidence * 100).toStringAsFixed(0)}% via $source',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          if (album.tracklist.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Tracklist', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...album.tracklist.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${entry.key + 1}. ${entry.value}'),
                )),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save),
              label: const Text('Save to Collection'),
            ),
          ),
        ],
      ),
    );
  }
}
