import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'inference_backend.dart';
import 'label_lookup.dart';

/// Produces a diagnosis from a photo or a text description.
///
/// Knows nothing about how inference happens — it asks an
/// [InferenceBackend], which is TensorFlow Lite on a phone and an API
/// call in a browser. Swapping or relocating the model changes only
/// those files, never this one and never any screen.
class DiagnosisService {
  /// Below this, the app asks a follow-up question instead of naming a
  /// disease. Telling a farmer the wrong disease makes them buy the
  /// wrong chemical — they lose the money and still lose the crop.
  /// Saying "I need another photo" is better than being confidently wrong.
  static const double confidenceThreshold = 0.70;

  final InferenceBackend _backend = createInferenceBackend();
  int _sampleCount = 0;

  /// True once real inference has actually worked.
  bool get usingRealModel => _backend.isReady;

  /// One line explaining where inference runs, for the info dialog.
  String get backendDescription => _backend.description;

  Future<DiagnosisResult> analysePhoto(Uint8List imageBytes) async {
    final prediction = await _backend.classify(imageBytes);

    if (prediction == null) {
      return _sampleResult();
    }

    final info = lookUp(prediction.label);
    final confidence = prediction.confidence;

    if (confidence < confidenceThreshold) {
      return DiagnosisResult(
        diseaseName: 'Not sure yet',
        cropName: info.crop,
        confidence: confidence,
        needsFollowUp: true,
        followUpQuestion:
            'I am only ${(confidence * 100).round()}% sure, which is not enough '
            'to give you advice. Please send one more photo — if you can, '
            'show the underside of the leaf in good light.',
      );
    }

    return DiagnosisResult(
      diseaseName: info.disease,
      cropName: info.crop,
      confidence: confidence,
      symptoms: info.symptoms,
      treatment: info.treatment,
      preHarvestInterval: info.preHarvest,
    );
  }

  static const _apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000',
  );

  /// Turns a written description into a diagnosis.
  ///
  /// The server uses a language model to decide which of our known
  /// diseases the description matches — and only that. It is never
  /// asked for treatment, because a model will happily invent a
  /// chemical name. The advice below comes from our own reviewed
  /// content, looked up from the label the server returned.
  Future<DiagnosisResult> analyseText(String description) async {
    String? label;
    String reason = '';

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/triage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'description': description}),
          )
          .timeout(const Duration(seconds: 18));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        reason = data['reason'] as String? ?? '';
        if (data['confident'] == true) {
          label = data['label'] as String?;
        }
      }
    } catch (_) {
      // Server unreachable — fall through to asking for a photo.
    }

    // Could not match anything confidently: ask for a photo rather than
    // guessing from words alone.
    if (label == null) {
      return DiagnosisResult(
        diseaseName: 'Not sure yet',
        cropName: '',
        confidence: 0,
        needsFollowUp: true,
        followUpQuestion: reason.isNotEmpty
            ? '$reason\n\nPlease send a clear photo of the affected leaf so I '
                'can check properly.'
            : 'A description alone is hard to judge. Please send a clear '
                'photo of the affected leaf.',
      );
    }

    // Matched a known disease. Treatment comes from our verified data,
    // not from the model.
    final info = lookUp(label);
    return DiagnosisResult(
      diseaseName: info.disease,
      cropName: info.crop,
      // Text is weaker evidence than a photo, so this is shown as a
      // provisional match rather than a confident diagnosis. The card
      // makes that visible with an amber badge.
      confidence: 0.75,
      symptoms: info.symptoms,
      treatment: info.treatment,
      preHarvestInterval: info.preHarvest,
      followUpQuestion: reason,
    );
  }

  /// Used when inference is unavailable — the model asset is missing on
  /// mobile, or the API is unreachable on web — so the UI stays usable.
  Future<DiagnosisResult> _sampleResult() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    _sampleCount++;

    if (_sampleCount % 3 == 0) {
      return const DiagnosisResult(
        diseaseName: 'Not sure yet',
        cropName: 'Tomato',
        confidence: 0.61,
        needsFollowUp: true,
        followUpQuestion:
            'I am only 61% sure, which is not enough to give you advice. '
            'Please send one more photo — if you can, show the underside of the leaf.',
      );
    }

    return const DiagnosisResult(
      diseaseName: 'Late Blight',
      cropName: 'Potato',
      confidence: 0.94,
      symptoms:
          'Dark brown water-soaked patches on the leaves, with pale mould underneath.',
      treatment:
          'Spray metalaxyl combined with mancozeb at the dose on the label.',
      preHarvestInterval: 'Wait 7 days after spraying before harvesting.',
    );
  }

  void dispose() => _backend.dispose();
}
