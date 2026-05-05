import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import 'bloc/camera_bloc.dart';
import '../scan_result/scan_result_screen.dart';
import '../scan_result/edit_preview_screen.dart';
import '../scan_result/manual_search_screen.dart';

/// Camera screen for album scanning - optimized for one-handed use.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
    context.read<CameraBloc>().add(InitializeCamera());
  }

  Future<void> _requestPermissions() async {
    // On Android 13+ we need READ_MEDIA_IMAGES for gallery and camera
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraCaptureSuccess) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditPreviewScreen(imagePath: state.imagePath),
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                // Top bar
                _buildTopBar(state),
                // Camera viewfinder
                Expanded(child: _buildCameraPreview(state)),
                // Bottom controls (one-handed zone)
                _buildBottomControls(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(CameraState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Scan Album',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              // Manual search button
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.textPrimary),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManualSearchScreen(),
                    ),
                  );
                },
                tooltip: 'Manual Search',
              ),
              if (state is CameraReadyState)
                IconButton(
                  icon: Icon(
                    state.isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => context.read<CameraBloc>().add(ToggleFlash()),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(CameraState state) {
    if (state is CameraInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state is CameraError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                state.message,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<CameraBloc>().add(InitializeCamera());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              // Fallback: manual search even without camera
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManualSearchScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text('Search Manually Instead'),
              ),
            ],
          ),
        ),
      );
    }

    final bloc = context.read<CameraBloc>();
    if (bloc.controller != null && bloc.controller!.value.isInitialized) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(bloc.controller!),
              // Scan frame overlay
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Point at album cover',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBottomControls(CameraState state) {
    final isCapturing = state is CameraCapturing;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button
          GestureDetector(
            onTap: _pickFromGallery,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Capture button (large, centered)
          GestureDetector(
            onTap: isCapturing
                ? null
                : () => context.read<CameraBloc>().add(CapturePhoto()),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isCapturing ? null : AppColors.primaryGradient,
                color: isCapturing ? AppColors.surfaceLight : null,
                border: Border.all(
                  color: AppColors.primaryLight,
                  width: 3,
                ),
                boxShadow: isCapturing ? null : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: isCapturing
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
            ),
          ),
          // Switch camera
          GestureDetector(
            onTap: () => context.read<CameraBloc>().add(SwitchCamera()),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flip_camera_ios,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (image != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditPreviewScreen(imagePath: image.path),
        ),
      );
    }
  }
}

/// Displays the camera preview.
class CameraPreview extends StatelessWidget {
  final dynamic controller;

  const CameraPreview(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam, size: 64, color: AppColors.textTertiary),
      ),
    );
  }
}
