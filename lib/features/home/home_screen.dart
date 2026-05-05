import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../data/repositories/album_repository.dart';
import '../../data/services/recognition_service.dart';
import '../collection/bloc/collection_bloc.dart';
import '../camera/bloc/camera_bloc.dart';
import '../collection/collection_screen.dart';
import '../camera/scan_screen.dart';
import '../settings/settings_screen.dart';

/// Main app screen with bottom navigation for one-handed use.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // Start on Scan tab

  @override
  void initState() {
    super.initState();
    // Auto-test: after 3 seconds, run recognition on a test image
    _runAutoTest();
  }

  Future<void> _runAutoTest() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    const testPath = '/sdcard/Download/AlbumCovers/17_Radiohead_OK_Computer.jpg';
    debugPrint('[AutoTest] Starting auto-recognition test with $testPath');
    
    try {
      final recognition = context.read<RecognitionService>();
      final result = await recognition.recognizeFromImage(testPath);
      debugPrint('[AutoTest] RESULT: state=${result.state}, message=${result.message}');
      if (result.album != null) {
        debugPrint('[AutoTest] Album: ${result.album!.artist} - ${result.album!.title}');
      }
    } catch (e) {
      debugPrint('[AutoTest] ERROR: $e');
    }
  }

  final List<Widget> _screens = const [
    CollectionScreen(),
    ScanScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AlbumRepository>();
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          BlocProvider(
            create: (_) => CollectionBloc(repository)..add(LoadCollection()),
            child: const CollectionScreen(),
          ),
          BlocProvider(
            create: (_) => CameraBloc(),
            child: const ScanScreen(),
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index != _currentIndex) {
              HapticService.selection();
            }
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.primary.withOpacity(0.15),
          height: 64,
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: false,
                child: Icon(Icons.album_outlined, color: _currentIndex == 0 ? AppColors.primary : AppColors.textTertiary),
              ),
              selectedIcon: Icon(Icons.album, color: AppColors.primary),
              label: 'Collection',
            ),
            NavigationDestination(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _currentIndex == 1
                      ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
                      : null,
                  color: _currentIndex == 1 ? null : AppColors.surfaceLight,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: _currentIndex == 1 ? Colors.white : AppColors.textTertiary,
                  size: 18,
                ),
              ),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: _currentIndex == 2 ? AppColors.primary : AppColors.textTertiary),
              selectedIcon: Icon(Icons.settings, color: AppColors.primary),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
