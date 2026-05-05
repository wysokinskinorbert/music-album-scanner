import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class SmolVLMService {
  static const MethodChannel _channel =
      MethodChannel('com.albumscanner.music_album_scanner/smolvlm');

  bool _isModelLoaded = false;
  bool _isInitializing = false;

  /// Czy model jest załadowany
  bool get isModelLoaded => _isModelLoaded;

  /// Inicjalizacja modelu
  Future<bool> initializeModel() async {
    if (_isModelLoaded) return true;
    if (_isInitializing) {
      // Czekaj na zakończenie inicjalizacji
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isModelLoaded;
    }

    _isInitializing = true;
    try {
      // Sprawdź czy model istnieje w filesDir
      final appDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDir.path}/models/SmolVLM-256M-Instruct-Q8_0.gguf');
      final mmprojFile = File('${appDir.path}/models/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf');

      if (!modelFile.existsSync() || !mmprojFile.existsSync()) {
        print('SmolVLM: Model files not found');
        _isInitializing = false;
        return false;
      }

      final result = await _channel.invokeMethod<bool>('initializeModel');
      _isModelLoaded = result ?? false;
      return _isModelLoaded;
    } catch (e) {
      print('SmolVLM: Error initializing model: $e');
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Rozpoznanie albumu z okładki
  Future<String> recognizeAlbum(String imagePath) async {
    if (!_isModelLoaded) {
      final initialized = await initializeModel();
      if (!initialized) {
        return 'Error: Model not initialized';
      }
    }

    try {
      final result = await _channel.invokeMethod<String>('recognizeAlbum', {
        'imagePath': imagePath,
      });
      return result ?? 'Error: No response';
    } catch (e) {
      print('SmolVLM: Error recognizing album: $e');
      return 'Error: $e';
    }
  }

  /// Pobieranie modelu z HuggingFace
  Future<bool> downloadModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      if (!modelsDir.existsSync()) {
        modelsDir.createSync(recursive: true);
      }

      final modelFile = File('${modelsDir.path}/SmolVLM-256M-Instruct-Q8_0.gguf');
      final mmprojFile = File('${modelsDir.path}/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf');

      if (modelFile.existsSync() && mmprojFile.existsSync()) {
        print('SmolVLM: Model already downloaded');
        return true;
      }

      print('SmolVLM: Downloading model...');

      // Download model (175MB)
      final modelUrl = 'https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main/SmolVLM-256M-Instruct-Q8_0.gguf';
      await _downloadFile(modelUrl, modelFile);

      // Download mmproj (104MB)
      final mmprojUrl = 'https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf';
      await _downloadFile(mmprojUrl, mmprojFile);

      print('SmolVLM: Model downloaded successfully');
      return true;
    } catch (e) {
      print('SmolVLM: Error downloading model: $e');
      return false;
    }
  }

  Future<void> _downloadFile(String url, File file) async {
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    await response.pipe(file.openWrite());
    print('SmolVLM: Downloaded ${file.path} (${file.lengthSync()} bytes)');
  }

  /// Zwolnienie modelu
  Future<void> release() async {
    try {
      await _channel.invokeMethod('releaseModel');
      _isModelLoaded = false;
    } catch (e) {
      print('SmolVLM: Error releasing model: $e');
    }
  }
}
