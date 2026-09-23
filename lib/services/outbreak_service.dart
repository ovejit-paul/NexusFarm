import 'dart:convert';
import 'package:http/http.dart' as http;

/// An aggregated warning for one district.
class Outbreak {
  final String district;
  final String crop;
  final String disease;
  final int reportCount;
  final int daysSpan;

  const Outbreak({
    required this.district,
    required this.crop,
    required this.disease,
    required this.reportCount,
    required this.daysSpan,
  });

  factory Outbreak.fromJson(Map<String, dynamic> json) => Outbreak(
        district: json['district'] as String,
        crop: json['crop'] as String,
        disease: json['disease'] as String,
        reportCount: json['report_count'] as int,
        daysSpan: json['days_span'] as int,
      );

  /// The sentence shown in the banner.
  String get message {
    final days = daysSpan == 1 ? 'day' : 'days';
    return '$reportCount farmers in $district reported $disease in '
        '${crop.toLowerCase()} in the last $daysSpan $days. '
        'Check your field today.';
  }
}

/// Talks to the outbreak endpoints.
///
/// Reporting is deliberately fire-and-forget: if the server is down,
/// the farmer's own diagnosis still worked and they should not see an
/// error about a background upload they never asked for.
class OutbreakService {
  static const _apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000',
  );

  static const _timeout = Duration(seconds: 10);

  /// Sends one confident diagnosis towards the district count.
  ///
  /// Only the disease, crop and district go — no photo, no name, no
  /// location beyond the district the farmer typed in themselves.
  Future<void> reportScan({
    required String district,
    required String crop,
    required String disease,
    required double confidence,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$_apiBase/reports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'district': district,
              'crop': crop,
              'disease': disease,
              'confidence': confidence,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      // Swallowed on purpose. A missed report slightly under-counts the
      // district; surfacing it would interrupt a farmer over something
      // that is not their problem.
    }
  }

  /// Warnings for one district. Empty is the normal, healthy case.
  Future<List<Outbreak>> fetchOutbreaks(String district) async {
    try {
      final response = await http
          .get(Uri.parse('$_apiBase/outbreaks?district=$district'))
          .timeout(_timeout);

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['outbreaks'] as List)
          .map((o) => Outbreak.fromJson(o as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
