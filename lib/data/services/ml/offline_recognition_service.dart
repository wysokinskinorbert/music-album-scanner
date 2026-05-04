import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/constants/app_constants.dart';

/// Offline album cover recognition using TFLite.
class OfflineRecognitionService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  /// Check if the offline model is available.
  bool get isModelLoaded => _isModelLoaded;

  /// Load the TFLite model from assets.
  Future<bool> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/${AppConstants.offlineModelName}',
        options: InterpreterOptions()..threads = 4,
      );
      _isModelLoaded = true;
      return true;
    } catch (e) {
      _isModelLoaded = false;
      return false;
    }
  }

  /// Recognize album from image file.
  Future<RecognitionResultInternal?> recognize(String imagePath) async {
    if (!_isModelLoaded || _interpreter == null) return null;

    final imageBytes = File(imagePath).readAsBytesSync();
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // Resize to model input size (224x224 for MobileNet)
    final resized = img.copyResize(image, width: 224, height: 224);

    // Convert to normalized float32 tensor
    final input = Float32List(224 * 224 * 3);
    int idx = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);
        input[idx++] = (pixel.r as int) / 255.0;
        input[idx++] = (pixel.g as int) / 255.0;
        input[idx++] = (pixel.b as int) / 255.0;
      }
    }

    final inputTensor = input.reshape([1, 224, 224, 3]);
    final output = List.filled(1, List.filled(1000, 0.0))
        .reshape([1, 1000]) as List<List<double>>;

    _interpreter!.run(inputTensor, output);

    // Find top prediction
    final predictions = output[0];
    int maxIdx = 0;
    double maxVal = 0.0;
    for (int i = 0; i < predictions.length; i++) {
      if (predictions[i] > maxVal) {
        maxVal = predictions[i];
        maxIdx = i;
      }
    }

    return RecognitionResultInternal(
      labelIndex: maxIdx,
      confidence: maxVal,
    );
  }

  /// Dispose of the interpreter.
  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
  }
}

/// Internal recognition result from TFLite model.
class RecognitionResultInternal {
  final int labelIndex;
  final double confidence;

  const RecognitionResultInternal({
    required this.labelIndex,
    required this.confidence,
  });
}
