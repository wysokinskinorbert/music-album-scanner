import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/album_model.dart';
import 'bloc/scan_result_bloc.dart';

/// Dedicated screen for manual album search by text input.
class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({super.key});

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSearching = false;

  @override
  void dispose() {
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manual Search'),
      ),
      body: BlocConsumer<ScanResultBloc, ScanResultState>(
        listener: (context, state) {
          if (state is ScanResultSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${state.album.title}" added to collection!'),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Text(
                    'Search for an album',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the artist name and album title to search MusicBrainz and Discogs.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Artist field
                  _buildTextField(
                    controller: _artistController,
                    label: 'Artist',
                    hint: 'e.g. Radiohead',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  // Album field
                  _buildTextField(
                    controller: _albumController,
                    label: 'Album',
                    hint: 'e.g. OK Computer',
                    icon: Icons.album_outlined,
                  ),
                  const SizedBox(height: 28),

                  // Search button
                  _buildSearchButton(state),
                  const SizedBox(height: 24),

                  // Results area
                  if (state is ScanResultProcessing)
                    _buildSearchingState()
                  else if (state is ScanResultSuccess)
                    _buildResultCard(state)
                  else if (state is ScanResultFailure)
                    _buildErrorCard(state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textTertiary),
      ),
      validator: (value) {
        if (controller == _artistController && (value == null || value.trim().isEmpty)) {
          return 'Please enter an artist name';
        }
        return null;
      },
      textInputAction: controller == _artistController
          ? TextInputAction.next
          : TextInputAction.search,
      onFieldSubmitted: (_) {
        if (controller == _artistController) {
          FocusScope.of(context).nextFocus();
        } else {
          _performSearch();
        }
      },
    );
  }

  Widget _buildSearchButton(ScanResultState state) {
    final isProcessing = state is ScanResultProcessing;
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isProcessing ? null : _performSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Search',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Searching MusicBrainz...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ScanResultSuccess state) {
    final album = state.album;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.confidence >= 0.8 ? AppColors.success : AppColors.warning,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: state.confidence >= 0.8 ? AppColors.success : AppColors.warning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(state.confidence * 100).toInt()}% match',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.source,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title + Artist
          Text(
            album.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            album.artist,
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Metadata
          if (album.releaseYear != null)
            _buildMetaRow(Icons.calendar_today, '${album.releaseYear}'),
          if (album.label != null)
            _buildMetaRow(Icons.label, album.label!),
          if (album.genre != null)
            _buildMetaRow(Icons.music_note, album.genre!),
          if (album.country != null)
            _buildMetaRow(Icons.flag, album.country!),

          // Tracklist preview
          if (album.tracklist.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${album.tracklist.length} tracks',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<ScanResultBloc>().add(ConfirmAndSave(album: album));
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add to Collection',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ScanResultFailure state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 40, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            state.message,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try different keywords or check the spelling.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _performSearch() {
    if (!_formKey.currentState!.validate()) return;

    final artist = _artistController.text.trim();
    final album = _albumController.text.trim();

    context.read<ScanResultBloc>().add(
          ManualSearch(artist: artist, album: album),
        );
  }
}
