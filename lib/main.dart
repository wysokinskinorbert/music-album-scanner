import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/network/connectivity_service.dart';
import 'core/services/haptic_service.dart';
import 'data/services/storage/local_storage_service.dart';
import 'data/services/recognition_service.dart';
import 'data/services/api/musicbrainz_service.dart';
import 'data/services/api/discogs_service.dart';
import 'data/services/ml/text_extraction_service.dart';
import 'data/services/ml/image_labeling_service.dart';
import 'data/services/ml/barcode_scanning_service.dart';
import 'data/repositories/album_repository.dart';
import 'features/camera/bloc/camera_bloc.dart';
import 'features/collection/bloc/collection_bloc.dart';
import 'features/scan_result/bloc/scan_result_bloc.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage
  final storage = LocalStorageService();
  await storage.init();

  // Initialize haptic feedback
  await HapticService.init();

  // Initialize API client
  final apiClient = ApiClient();

  // Initialize sub-services
  final connectivity = ConnectivityService();
  final musicBrainz = MusicBrainzService(apiClient);
  final discogs = DiscogsService(apiClient);
  final textExtractor = TextExtractionService();
  final imageLabeler = ImageLabelingService();
  final barcodeScanner = BarcodeScanningService();

  // Initialize recognition service with all dependencies
  final recognition = RecognitionService(
    musicBrainz: musicBrainz,
    discogs: discogs,
    textExtractor: textExtractor,
    imageLabeler: imageLabeler,
    barcodeScanner: barcodeScanner,
    connectivity: connectivity,
  );
  final repository = AlbumRepository(storage);

  runApp(MusicAlbumScannerApp(
    storage: storage,
    recognition: recognition,
    repository: repository,
    connectivity: connectivity,
  ));
}

class MusicAlbumScannerApp extends StatelessWidget {
  final LocalStorageService storage;
  final RecognitionService recognition;
  final AlbumRepository repository;
  final ConnectivityService connectivity;

  const MusicAlbumScannerApp({
    super.key,
    required this.storage,
    required this.recognition,
    required this.repository,
    required this.connectivity,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AlbumRepository>.value(value: repository),
        RepositoryProvider<RecognitionService>.value(value: recognition),
        RepositoryProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => CollectionBloc(repository)..add(LoadCollection()),
          ),
          BlocProvider(create: (_) => CameraBloc()),
          BlocProvider(
            create: (_) => ScanResultBloc(
              recognition: recognition,
              repository: repository,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Album Scanner',
          theme: AppTheme.darkTheme,
          debugShowCheckedModeBanner: false,
          home: const _AppEntry(),
        ),
      ),
    );
  }
}

/// Entry point that checks onboarding status.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _showOnboarding = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await OnboardingScreen.isCompleted();
    if (mounted) {
      setState(() {
        _showOnboarding = !completed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: () {
          setState(() => _showOnboarding = false);
        },
      );
    }

    return const HomeScreen();
  }
}
