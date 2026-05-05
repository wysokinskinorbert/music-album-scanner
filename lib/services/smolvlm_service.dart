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
