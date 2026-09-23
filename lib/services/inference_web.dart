import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'inference_backend.dart';

InferenceBackend createBackend() => WebInference();

/// Sends the image to our own API and returns what it predicts.
///
/// A browser cannot load the native TensorFlow Lite library, so the
/// same model is served from a small Python endpoint instead. This is
/// a browser limitation, not a change of approach — the mobile build
/// still runs everything on the device.
class WebInference implements InferenceBackend {
  /// Point this at the deployed API. Left as a compile-time constant
  /// so it can be overridden at build time:
  ///   flutter build web --dart-define=API_BASE=https://your-api.com
  static const _apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000',
  );

  static const _timeout = Duration(seconds: 20);

  bool _lastCallSucceeded = false;

  @override
  bool get isReady => _lastCallSucceeded;

  @override
  String get description =>
      'In the browser the same trained model runs on our server, because '
      'a browser cannot load the native model library. The phone version '
      'runs it fully offline on the device.';

  @override
  Future<Prediction?> classify(Uint8List imageBytes) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image': base64Encode(imageBytes)}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        _lastCallSucceeded = false;
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _lastCallSucceeded = true;

      return Prediction(
        data['label'] as String,
        (data['confidence'] as num).toDouble(),
      );
    } catch (_) {
      // Server unreachable, timed out, or returned something unexpected.
      // Caller falls back to sample results rather than showing an error,
      // so a demo never dies on a flaky connection.
      _lastCallSucceeded = false;
      return null;
    }
  }

  @override
  void dispose() {}
}
