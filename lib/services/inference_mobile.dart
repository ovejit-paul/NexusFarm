import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'inference_backend.dart';

InferenceBackend createBackend() => MobileInference();

/// Runs the trained model on the handset itself — no internet needed,
/// and no photo leaves the device.
///
/// Takes raw bytes rather than a File so the same call signature works
/// on both platforms; only this file ever touches TensorFlow Lite.
class MobileInference implements InferenceBackend {
  static const _modelAsset = 'assets/model/model.tflite';
  static const _labelsAsset = 'assets/model/labels.txt';
  static const _inputSize = 224;

  Interpreter? _interpreter;
  List<String>? _labels;
  bool _triedLoading = false;

  @override
  bool get isReady => _interpreter != null && _labels != null;

  @override
  String get description =>
      'The model runs on this phone. No internet is needed and no photo '
      'leaves the device.';

  Future<void> _load() async {
    if (_triedLoading) return;
    _triedLoading = true;

    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      final raw = await rootBundle.loadString(_labelsAsset);
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (_) {
      // Model not bundled yet — caller falls back to sample results.
      _interpreter = null;
      _labels = null;
    }
  }

  @override
  Future<Prediction?> classify(Uint8List imageBytes) async {
    await _load();
    if (!isReady) return null;

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final resized =
        img.copyResize(decoded, width: _inputSize, height: _inputSize);

    // IMPORTANT: values stay in the 0-255 range, NOT divided by 255.
    // The training script puts EfficientNet's preprocess_input inside
    // the model graph, so the model normalises its own input. Scaling
    // here as well would scale twice and wreck the predictions.
    final input = [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
        }),
      )
    ];

    final output =
        List.filled(_labels!.length, 0.0).reshape([1, _labels!.length]);

    _interpreter!.run(input, output);

    final scores = List<double>.from(output[0] as List);
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }

    return Prediction(_labels![best], scores[best]);
  }

  @override
  void dispose() => _interpreter?.close();
}
