import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'data/models/album_model.dart';
import 'data/models/album_model.g.dart';
import 'data/repositories/album_repository.dart';
import 'data/services/storage/local_storage_service.dart';
import 'data/services/recognition_service.dart';
import 'data/services/ml/text_extraction_service.dart';
import 'data/services/ml/image_labeling_service.dart';
import 'core/network/api_client.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDir = await getApplicationDocumentsDirectory();
  Hive.init(appDir.path);
  Hive.registerAdapter(AlbumAdapter());

  final apiClient = ApiClient();
  final storage = LocalStorageService();
  await storage.init();

  final textExtraction = TextExtractionService();
  final imageLabeler = ImageLabelingService();

  final recognition = RecognitionService(
    apiClient: apiClient,
    textExtraction: textExtraction,
    imageLabeler: imageLabeler,
  );
  final repository = AlbumRepository(storage);

  runApp(MusicAlbumScannerApp(
    recognition: recognition,
    repository: repository,
    storage: storage,
  ));
}

class MusicAlbumScannerApp extends StatelessWidget {
  final RecognitionService recognition;
  final AlbumRepository repository;
  final LocalStorageService storage;

  const MusicAlbumScannerApp({
    super.key,
    required this.recognition,
    required this.repository,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RecognitionService>.value(value: recognition),
        RepositoryProvider<AlbumRepository>.value(value: repository),
        RepositoryProvider<LocalStorageService>.value(value: storage),
      ],
      child: MaterialApp(
        title: 'Music Album Scanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
