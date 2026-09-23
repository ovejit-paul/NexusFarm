import 'dart:typed_data';

// Picks the right implementation at compile time. Neither file is even
// parsed on the wrong platform, which is what keeps dart:io out of the
// web build and dart:html out of the mobile build.
import 'inference_mobile.dart'
    if (dart.library.html) 'inference_web.dart' as impl;

/// What every inference backend must return.
class Prediction {
  final String label;
  final double confidence;

  const Prediction(this.label, this.confidence);
}

/// One interface, two implementations:
///   mobile -> TensorFlow Lite, runs on the handset, no network
///   web    -> HTTP call to our own API, because browsers cannot run
///             the native TFLite library
abstract class InferenceBackend {
  Future<Prediction?> classify(Uint8List imageBytes);

  /// True once the backend is confirmed working. On mobile this means
  /// the model asset loaded; on web it means the API answered.
  bool get isReady;

  /// Shown in the "How this works" dialog so the audience can see
  /// which path is actually running.
  String get description;

  void dispose();
}

/// Built by whichever implementation file was compiled in.
InferenceBackend createInferenceBackend() => impl.createBackend();
