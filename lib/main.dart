import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/network/connectivity_service.dart';
import 'data/services/storage/local_storage_service.dart';
import 'data/services/recognition_service.dart';
import 'data/repositories/album_repository.dart';
import 'features/camera/bloc/camera_bloc.dart';
import 'features/collection/bloc/collection_bloc.dart';
import 'features/scan_result/bloc/scan_result_bloc.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage
  final storage = LocalStorageService();
  await storage.init();

  // Initialize services
  final apiClient = ApiClient();
  final connectivity = ConnectivityService();
  final recognition = RecognitionService(
    apiClient: apiClient,
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
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
