import 'package:flutter/foundation.dart';
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
    _runBatchTest();
  }

  Future<void> _runBatchTest() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final recognition = context.read<RecognitionService>();

    final covers = [
      '01_Aphex_Twin_Selected_Ambient_Works_85-92.jpg',
      '02_Bjork_Homogenic.jpg',
      '03_Black_Sabbath_Paranoid.jpg',
      '04_Boards_of_Canada_Music_Has_the_Right_to_Children.jpg',
      '05_Burial_Untrue.jpg',
      '06_Can_Tago_Mago.jpg',
      '07_Daft_Punk_Discovery.jpg',
      '08_Fela_Kuti_Zombie.jpg',
      '09_Fleetwood_Mac_Rumours.jpg',
      '10_Kendrick_Lamar_To_Pimp_a_Butterfly.jpg',
      '11_King_Gizzard_Nonagon_Infinity.jpg',
      '12_Madvillain_Madvillainy.jpg',
      '13_Massive_Attack_Mezzanine.jpg',
      '14_Metallica_Master_of_Puppets.jpg',
      '15_Miles_Davis_Kind_of_Blue.jpg',
      '16_Nusrat_Fateh_Ali_Khan_Mustt_Mustt.jpg',
      '17_Radiohead_OK_Computer.jpg',
      '18_Sigur_Ros_Agaetis_byrjun.jpg',
      '19_Talking_Heads_Remain_in_Light.jpg',
    ];

    debugPrint('╔══════════════════════════════════════════╗');
    debugPrint('║       BATCH RECOGNITION TEST START       ║');
    debugPrint('╚══════════════════════════════════════════╝');

    int ok = 0;
    int fail = 0;

    for (final cover in covers) {
      final path = '/sdcard/Download/AlbumCovers/$cover';
      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ TEST: $cover');

      try {
        final result = await recognition.recognizeFromImage(path);
        if (result.album != null) {
          debugPrint('│ OK: ${result.album!.artist} - ${result.album!.title} (score: ${(result.confidence * 100).toStringAsFixed(0)}%)');
          ok++;
        } else {
          debugPrint('│ FAIL: ${result.message}');
          fail++;
        }
      } catch (e) {
        debugPrint('│ ERROR: $e');
        fail++;
      }

      debugPrint('└──────────────────────────────────────────');
      await Future.delayed(const Duration(seconds: 2));
    }

    debugPrint('╔══════════════════════════════════════════╗');
    debugPrint('║  BATCH TEST DONE: $ok OK, $fail FAIL out of ${covers.length}');
    debugPrint('╚══════════════════════════════════════════╝');
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
