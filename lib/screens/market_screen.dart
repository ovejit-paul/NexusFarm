import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/market_service.dart';

/// Knowing the day's price is one of the most practical things a
/// farmer needs — it decides whether to sell now or hold, and whether
/// a trader's offer is fair.
///
/// Prices come from our API, which serves a cache refreshed from the
/// Department of Agricultural Marketing. The screen always says how
/// old the figures are, because a stale price presented as today's is
/// worse than no price at all.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _service = MarketService();
  late Future<PriceSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchPrices();
  }

  Future<void> _refresh() async {
    final future = _service.fetchPrices();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Prices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<PriceSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null || data.prices.isEmpty) {
            return const Center(child: Text('No prices available'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sourceBanner(data),
                const SizedBox(height: 12),
                for (final price in data.prices) _row(price),
                const SizedBox(height: 20),
                const Text(
                  'Wholesale price range per kg. What a trader offers at the '
                  'farm gate is normally lower.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Says plainly where the numbers came from and how old they are.
  Widget _sourceBanner(PriceSnapshot data) {
    final stale = data.ageHours > 36;
    final offline = data.isFallback;

    final color = offline
        ? AppColors.warning
        : (stale ? AppColors.warning : AppColors.primary);

    String line;
    if (offline) {
      line = 'Could not reach the server. Showing typical prices, not today\'s.';
    } else if (data.ageHours < 1) {
      line = 'Updated just now';
    } else if (data.ageHours < 24) {
      line = 'Updated ${data.ageHours.round()} hours ago';
    } else {
      final days = (data.ageHours / 24).round();
      line = 'Updated $days ${days == 1 ? 'day' : 'days'} ago';
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            offline
                ? Icons.cloud_off
                : (stale ? Icons.schedule : Icons.storefront),
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.source,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(CropPrice price) {
    final change = price.changePercent;
    final rising = change != null && change > 0;
    final falling = change != null && change < 0;

    final changeColor = rising
        ? AppColors.success
        : (falling ? AppColors.danger : AppColors.textSecondary);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price.crop,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (change != null) ...[
                        Icon(
                          rising
                              ? Icons.arrow_upward
                              : (falling ? Icons.arrow_downward : Icons.remove),
                          size: 13,
                          color: changeColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          change == 0
                              ? 'No change'
                              : '${change.abs().toStringAsFixed(1)}%',
                          style:
                              TextStyle(fontSize: 12, color: changeColor),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        price.market,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Tk ${price.low.round()} - ${price.high.round()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.primaryDark,
                  ),
                ),
                const Text(
                  'per kg',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
