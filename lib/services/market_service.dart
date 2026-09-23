import 'dart:convert';
import 'package:http/http.dart' as http;

/// One crop's price range on a given day.
class CropPrice {
  final String crop;
  final double low;
  final double high;
  final String market;

  /// Percent move since the previous reading. Null when there is
  /// nothing to compare against yet.
  final double? changePercent;

  const CropPrice({
    required this.crop,
    required this.low,
    required this.high,
    required this.market,
    this.changePercent,
  });

  double get mid => (low + high) / 2;

  factory CropPrice.fromJson(Map<String, dynamic> json) => CropPrice(
        crop: json['crop'] as String,
        low: (json['low'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
        market: json['market'] as String? ?? '',
        changePercent: json['change_percent'] == null
            ? null
            : (json['change_percent'] as num).toDouble(),
      );
}

/// A set of prices plus where and when they came from.
class PriceSnapshot {
  final List<CropPrice> prices;
  final String source;

  /// How old the figures are. Shown to the farmer so stale prices are
  /// never presented as today's.
  final double ageHours;

  /// True when this is built-in sample data rather than anything the
  /// server returned.
  final bool isFallback;

  const PriceSnapshot({
    required this.prices,
    required this.source,
    required this.ageHours,
    this.isFallback = false,
  });
}

/// Fetches prices from our API.
///
/// The API serves from its own cache and never scrapes on request, so
/// this call is fast. If the server is unreachable the app shows
/// built-in sample figures clearly marked as such — an offline farmer
/// gets a rough guide rather than a blank screen.
class MarketService {
  static const _apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000',
  );

  static const _timeout = Duration(seconds: 12);

  Future<PriceSnapshot> fetchPrices() async {
    try {
      final response = await http
          .get(Uri.parse('$_apiBase/prices'))
          .timeout(_timeout);

      if (response.statusCode != 200) return _fallback();

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final prices = (data['prices'] as List)
          .map((p) => CropPrice.fromJson(p as Map<String, dynamic>))
          .toList();

      if (prices.isEmpty) return _fallback();

      return PriceSnapshot(
        prices: prices,
        source: data['source'] as String? ?? 'Unknown source',
        ageHours: (data['age_hours'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return _fallback();
    }
  }

  /// Representative figures, used only when the server cannot be
  /// reached. Marked as fallback so the screen can say so.
  PriceSnapshot _fallback() => const PriceSnapshot(
        isFallback: true,
        source: 'Offline — showing typical prices, not today\'s',
        ageHours: 0,
        prices: [
          CropPrice(crop: 'Rice (coarse)', low: 48, high: 50, market: 'Dhaka'),
          CropPrice(crop: 'Rice (medium)', low: 55, high: 57, market: 'Dhaka'),
          CropPrice(crop: 'Potato', low: 25, high: 30, market: 'Dhaka'),
          CropPrice(crop: 'Tomato', low: 40, high: 50, market: 'Dhaka'),
          CropPrice(crop: 'Onion (local)', low: 60, high: 64, market: 'Dhaka'),
          CropPrice(crop: 'Lentil', low: 105, high: 115, market: 'Dhaka'),
        ],
      );
}
